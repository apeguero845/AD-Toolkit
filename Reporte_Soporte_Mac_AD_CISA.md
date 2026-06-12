# **Historial de Soporte Técnico: Integración macOS a Active Directory (César Iglesias S.A.)**

**Fecha de Registro:** 12 de junio de 2026

**Analista a Cargo:** Alam Peguero

**Equipo Afectado:** CILMACSDTI002

**Dominio:** cesariglesias.local

## **1\. Problema Inicial: Fallo al Unir Equipo al Dominio**

El intento inicial de ingresar una Mac al entorno de Active Directory mediante la interfaz gráfica (Utilidad de Directorios) fallaba arrojando un "Error desconocido". Al intentar forzar la unión mediante la Terminal usando el comando dsconfigad, el sistema presentó una serie de errores específicos.

### **Comandos de Diagnóstico Utilizados**

* **Comprobación de DNS:** ping \-c 4 cesariglesias.local y nslookup \-type=SRV \_ldap.\_tcp.dc.\_msdcs.cesariglesias.local  
* **Sincronización de Tiempo:** sudo sntp \-sS 172.16.7.250  
* **Limpieza de intentos previos:** sudo dsconfigad \-remove \-force \-computer "CILMACSDTI002" \-username "soportetecnicoti"

### **Errores Encontrados y Solucionados en el Proceso de Unión**

* **Error 2000 (Node name wasn't found)**  
  * **Causa:** Falla en la resolución DNS; la Mac no localizaba el servidor AD.  
  * **Resolución:** Se confirmó con comandos que la red estaba accesible.  
* **Error 5200 (Authentication server could not be contacted)**  
  * **Causa:** Desincronización de tiempo entre el reloj de la Mac y el Controlador de Dominio (Kerberos exige sincronía estricta).  
  * **Resolución:** Se forzó la sincronización manual del tiempo con el servidor.  
* **Error 5002 (Invalid credentials supplied)**  
  * **Causa:** Las credenciales suministradas en uno de los intentos no tenían permisos o se introdujeron incorrectamente.  
  * **Resolución:** Se ajustó la sintaxis y se utilizaron credenciales válidas.  
* **Error: Container does not exist**  
  * **Causa:** Active Directory bloqueaba el registro en el contenedor raíz por defecto (CN=Computers) debido a las políticas de seguridad de la infraestructura.  
  * **Resolución:** Se modificó el comando para especificar la ruta exacta (Distinguished Name) mediante el parámetro \-ou.

### **Comando Final Exitoso (Unión al Dominio)**

El comando que logró la integración definitiva especificando la estructura de Unidades Organizativas (OU):

sudo dsconfigad \-add cesariglesias.local \-computer "CILMACSDTI002" \-username "apeguero" \-ou "OU=CISA\_Laptops,OU=CISA\_Computers,DC=cesariglesias,DC=local" \-force

### **Notas sobre Nomenclatura en Active Directory**

Se observó que el sistema macOS normaliza el nombre del equipo a minúsculas (cilmacsdti002) al registrarlo, independientemente de cómo se escriba en el comando. Esto es una medida de seguridad hardcoded de Apple para evitar fallos de DNS y Kerberos. Para mantener el estándar corporativo (mayúsculas), el renombrado debe hacerse visualmente ("Display Name") desde la consola de *Usuarios y equipos de Active Directory (ADUC)*.

## **2\. Desarrollo de Aplicación de Autoservicio: Cambio de Contraseña**

Como iniciativa de soporte, se intentó desarrollar una aplicación nativa en AppleScript para permitir a los usuarios cambiar su contraseña de Active Directory directamente desde la Mac sin intervención de TI.

### **Iteración 1: Comando dscl**

Se desarrolló un script utilizando dscl . \-passwd.

* **Resultado:** Fallo con error.  
* **Error Recibido:** DS Error: \-14165 (eDSAuthPasswordQualityCheckFailed)  
* **Causa:** El servidor AD rechazó la clave por no cumplir con las políticas de complejidad (GPO) de la empresa.

### **Iteración 2: Comando sysadminctl (Moderno)**

Se actualizó el script para utilizar la herramienta nativa moderna de Apple, esperando mejor compatibilidad y sincronización automática del Llavero (Keychain).

* **Resultado:** Fallo técnico subyacente.  
* **Error Recibido (Previo a adaptación):** DS Error: \-14091 (eDSAuthMethodNotSupported)  
* **Comportamiento Anómalo (Desincronización):** Tras ejecutar sysadminctl, la Mac reportó "Éxito". La contraseña se actualizó localmente en el equipo, pero pruebas en incógnito en el Webmail confirmaron que **la contraseña anterior seguía activa en Active Directory**.  
* **Causa Raíz:** Las estrictas políticas de seguridad del servidor AD de la empresa (posiblemente requiriendo LDAPS) rechazan los métodos de cambio de contraseña enviados por las herramientas de comando de macOS, considerándolos "métodos no soportados". El script falló silenciosamente al intentar comunicar el cambio a la red, creando una desincronización entre la cuenta local y la del dominio.

### **La Solución Definitiva (Protocolo Kerberos)**

Se concluyó que la única vía confiable por línea de comandos para hablar el lenguaje nativo del servidor de seguridad de Windows es a través de Kerberos.

Para forzar un cambio de contraseña directo al controlador de dominio desde una Mac, se debe utilizar el siguiente comando interactivo en la terminal (notar el dominio en mayúsculas):

kpasswd usuario@CESARIGLESIAS.LOCAL

### **Recomendación Final para Usuarios Finales**

Debido a la complejidad de automatizar comandos interactivos de Kerberos, se determinó que la ruta oficial y más segura para que los usuarios cambien su clave sin abrir tickets (y que garantiza la sincronización del servidor y el Llavero) es a través de la interfaz nativa del sistema:

1. Ir a **Configuración del Sistema** \> **Usuarios y grupos**.  
2. Clic en el ícono **( i )** junto a "Servidor de cuentas de red".  
3. Clic en **Cambiar contraseña...**