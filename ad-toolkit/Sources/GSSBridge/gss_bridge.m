//
//  gss_bridge.c
//  AD Toolkit
//
//  Implementation of Kerberos password change via GSS.framework.
//
//  Architecture:
//    gss_aapl_change_password() → GSSCred daemon → Heimdal Kerberos → KDC
//
//  This avoids the problems with:
//    - dscl . -passwd  (Error -14165: GPO complexity rejection)
//    - sysadminctl     (desync: local OK, AD unchanged)
//    - kpasswd CLI     (requires interactive /dev/tty)
//

#import "gss_bridge.h"
#import <GSS/gssapi.h>
#import <GSS/gssapi_apple.h>
#import <GSS/gssapi_krb5.h>
#import <stdlib.h>
#import <string.h>

gss_password_change_result_t gss_change_password(
    const char *userPrincipal,
    const char *oldPassword,
    const char *newPassword
) {
    gss_password_change_result_t result = { .success = false, .kerberos_error_code = 0, .error_message = NULL };

    if (!userPrincipal || !oldPassword || !newPassword) {
        result.error_message = strdup("Todos los parámetros son requeridos");
        return result;
    }

    // Create GSS name from user principal string
    // Format: userPrincipal@REALM (e.g., "jperez@CESARIGLESIAS.LOCAL")
    CFStringRef principalCF = CFStringCreateWithCString(kCFAllocatorDefault,
                                                        userPrincipal,
                                                        kCFStringEncodingUTF8);
    if (!principalCF) {
        result.error_message = strdup("Error al crear el principal name");
        return result;
    }

    gss_name_t gssName = GSSCreateName(principalCF,
                                        GSS_C_NT_USER_NAME,
                                        NULL);
    CFRelease(principalCF);

    if (!gssName) {
        result.error_message = strdup("Error al crear el nombre GSS");
        return result;
    }

    // Prepare old/new password attributes dictionary
    CFStringRef oldPassCF = CFStringCreateWithCString(kCFAllocatorDefault,
                                                      oldPassword,
                                                      kCFStringEncodingUTF8);
    CFStringRef newPassCF = CFStringCreateWithCString(kCFAllocatorDefault,
                                                      newPassword,
                                                      kCFStringEncodingUTF8);

    const void *keys[] = { kGSSChangePasswordOldPassword, kGSSChangePasswordNewPassword };
    const void *values[] = { oldPassCF, newPassCF };
    CFDictionaryRef attrs = CFDictionaryCreate(kCFAllocatorDefault,
                                                keys, values, 2,
                                                &kCFTypeDictionaryKeyCallBacks,
                                                &kCFTypeDictionaryValueCallBacks);

    CFErrorRef error = NULL;

    // Call Apple's GSS password change API
    // This communicates with the KDC over Kerberos protocol (tcp/464)
    OM_uint32 majorStatus = gss_aapl_change_password(
        gssName,
        GSS_KRB5_MECHANISM,
        attrs,
        &error
    );

    CFRelease(oldPassCF);
    CFRelease(newPassCF);
    CFRelease(attrs);

    if (majorStatus == GSS_S_COMPLETE) {
        result.success = true;
        result.error_message = NULL;
    } else {
        result.kerberos_error_code = (int)majorStatus;
        
        if (error) {
            CFStringRef errorDesc = CFErrorCopyDescription(error);
            if (errorDesc) {
                char errorBuf[512];
                CFStringGetCString(errorDesc, errorBuf, sizeof(errorBuf),
                                   kCFStringEncodingUTF8);
                result.error_message = strdup(errorBuf);
                CFRelease(errorDesc);
            }
            CFRelease(error);
        }

        // Map known error codes to user-friendly messages
        if (majorStatus == GSS_S_FAILURE) {
            if (result.error_message == NULL || result.error_message[0] == '\0') {
                free((void *)result.error_message);
                result.error_message = strdup("Error de autenticación Kerberos. "
                    "Verificá que la contraseña actual sea correcta.");
            } else {
                // Preserve the specific CFError description and append guidance
                const char *original = result.error_message;
                size_t len = strlen(original) + 100;
                char *enhanced = (char *)malloc(len);
                snprintf(enhanced, len, "%s — Verificá que la contraseña actual sea correcta.", original);
                free((void *)original);
                result.error_message = enhanced;
            }
        }
    }

    gss_release_name(&majorStatus, &gssName);
    return result;
}

const char *gss_error_description(int errorCode) {
    switch (errorCode) {
        case GSS_S_COMPLETE:
            return "Operación completada exitosamente";
        case GSS_S_FAILURE:
            return "Error de autenticación Kerberos. Verificá credenciales y conectividad de red.";
        case GSS_S_BAD_NAME:
            return "El nombre de usuario no es válido. Usá el formato: usuario@DOMINIO.LOCAL";
        case GSS_S_BAD_MECH:
            return "El mecanismo de autenticación no es soportado por el servidor.";
        case GSS_S_CREDENTIALS_EXPIRED:
            return "Las credenciales actuales expiraron. Contactá al administrador.";
        default:
            return "Error Kerberos desconocido. Revisá los logs para más detalles.";
    }
}
