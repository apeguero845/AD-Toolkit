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

/// Kerberos password change result codes (Heimdal KPASSWD protocol)
#define KPASSWD_ACCESSDENIED  4   // Wrong password or policy violation
#define KPASSWD_SOFTERROR     3   // Temporary KDC issue

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
    // Format: userPrincipal@REALM (e.g., "user@COMPANY.LOCAL")
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

        // Try to extract the underlying Kerberos error code from the CFError
        int kpasswdErrorCode = -1;
        if (error) {
            CFStringRef errorDesc = CFErrorCopyDescription(error);
            if (errorDesc) {
                char errorBuf[512];
                CFStringGetCString(errorDesc, errorBuf, sizeof(errorBuf),
                                   kCFStringEncodingUTF8);
                result.error_message = strdup(errorBuf);

                // Parse trailing ": N" — the Kerberos password change result code
                char *colon = strrchr(errorBuf, ':');
                if (colon && atoi(colon + 1) > 0) {
                    kpasswdErrorCode = atoi(colon + 1);
                }
                CFRelease(errorDesc);
            }
            CFRelease(error);
        }

        // Map known error codes to user-friendly messages
        if (majorStatus == GSS_S_FAILURE) {
            if (kpasswdErrorCode == KPASSWD_ACCESSDENIED) {
                // :4 = KRB5_KPASSWD_ACCESSDENIED
                // Could be wrong password OR password complexity violation.
                // Can't tell which from Kerberos alone — suggest both.
                free((void *)result.error_message);
                result.error_message = strdup(
                    "La contraseña actual no es correcta o la nueva contraseña "
                    "no cumple con las políticas de seguridad del dominio. "
                    "Verificá la contraseña actual e intentá con una nueva "
                    "contraseña que cumpla: 8+ caracteres, mayúscula, minúscula, "
                    "número y carácter especial.");
            } else if (kpasswdErrorCode == KPASSWD_SOFTERROR) {
                // :3 = KRB5_KPASSWD_SOFTERROR — temporary KDC issue
                free((void *)result.error_message);
                result.error_message = strdup(
                    "El servidor de dominio reportó un error temporal. "
                    "Esperá unos minutos e intentá de nuevo. "
                    "Si el error persiste, verificá que el KDC (puerto 464) "
                    "esté accesible desde esta Mac.");
            } else if (result.error_message && result.error_message[0] != '\0') {
                // Unknown error — preserve raw description with generic guidance
                const char *original = result.error_message;
                size_t len = strlen(original) + 80;
                char *enhanced = (char *)malloc(len);
                snprintf(enhanced, len, "%s — Contactá al administrador de TI.", original);
                free((void *)original);
                result.error_message = enhanced;
            } else {
                // No error description available — generic fallback
                result.error_message = strdup(
                    "Error al cambiar la contraseña. "
                    "Verificá la conexión de red y que el dominio sea accesible.");
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
