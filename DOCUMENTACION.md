# Guía de Desarrollo y Publicación de xIDE

Este documento recopila la arquitectura de desarrollo, las decisiones técnicas clave y el proceso detallado para compilar, firmar y publicar **xIDE** en la Apple App Store. Está diseñado para servir como referencia y documentación permanente del proyecto.

---

## 🎨 1. Arquitectura y Desarrollo de xIDE

**xIDE** es un entorno de desarrollo integrado (IDE) minimalista y nativo para iOS y iPadOS, diseñado para funcionar 100% sin conexión a Internet (*offline*).

### Componentes Principales:
*   **Shell Nativo en SwiftUI**: Proporciona la interfaz de usuario fluida, la navegación, la barra lateral de proyectos, los menús de configuración y el soporte nativo para **Drag & Drop** (arrastrar y soltar) del árbol de archivos.
*   **Monaco Code Editor**: El núcleo del editor es Monaco (motor de VS Code) ejecutándose dentro de un `WKWebView` (WebKit) altamente optimizado, lo que otorga autocompletado inteligente, resaltado de sintaxis (Dracula Theme por defecto) y atajos de teclado de escritorio.
*   **Intérprete Local Pyodide (WebAssembly)**: Un entorno de ejecución de Python completo corriendo localmente a través de Web Workers en el navegador interno. Permite ejecutar código matemático y lógica compleja de Python directamente en el chip de tu iPhone/iPad, sin necesidad de servidores remotos.
*   **Gestor de Archivos (FileManager)**: Capa intermedia en Swift que interactúa de forma segura con el almacenamiento del dispositivo, aislando los proyectos en espacios de trabajo (*workspaces*) protegidos dentro del contenedor seguro (*sandbox*) de la app.

---

## 🚀 2. Guía de Publicación en la App Store

El proceso de subir una aplicación móvil a la tienda de Apple requiere configuraciones estrictas de seguridad, propiedad intelectual, políticas de privacidad y empaquetado de recursos. A continuación se detallan los pasos para realizarlo con éxito.

---

### Paso 1: Configuración de la Cuenta de Apple Developer

1.  **Suscripción**: Requiere el registro en el [Apple Developer Program](https://developer.apple.com/) ($99 USD al año).
2.  **Sincronización inicial**: Tras procesar el pago, el sistema de Apple suele tardar entre **24 y 48 horas** en activar completamente los privilegios de desarrollo en App Store Connect.
3.  **Firma de Acuerdos**: Es mandatorio ir a [developer.apple.com/account](https://developer.apple.com/account) y aceptar cualquier contrato de licencia de software pendiente (*Program License Agreement*) que aparezca en el banner amarillo o rojo de la consola.

---

### Paso 2: Configuración de Firmas en Xcode (Signing & Capabilities)

Un error muy común al compilar por primera vez es:
> ❌ *Team "Personal Team" is not enrolled in the Apple Developer Program.*

Esto sucede porque Xcode intenta firmar la app con tu cuenta gratuita individual en lugar de tu suscripción de pago.

#### Solución:
1.  En Xcode, ve a **Settings** (o *Preferences*) > **Accounts** y añade tu Apple ID. Haz clic en el botón de actualización 🔄 para sincronizar las credenciales.
2.  Haz clic en la raíz del proyecto **xIDE** (icono azul a la izquierda) y selecciona el target **xIDE**.
3.  Ve a la pestaña **Signing & Capabilities**.
4.  En **Team**, selecciona tu nombre de desarrollador de pago (la opción que **NO** tiene el sufijo *"Personal Team"*).
5.  **Evitar colisiones de identificador**: Si el identificador (Bundle ID) se utilizó previamente con una cuenta gratuita, Apple lo bloquea temporalmente. Cambia el **Bundle Identifier** a uno único en tu cuenta de pago (ej. `com.alquimista.xIDE` o `com.malva.xideapp`).

---

### Paso 3: Preparación de Recursos Gráficos (Screenshots)

Apple es muy estricto con las dimensiones exactas de las capturas de pantalla de la app. Si subes dimensiones incorrectas, App Store Connect rechazará los archivos.

#### Dimensiones Requeridas:
*   **iPhone (Pantallas de 6.7")**: `1284 × 2778px` (o `1290 × 2796px`).
*   **iPad (Pantallas de 12.9")**: `2048 × 2732px` (o `2064 × 2752px`).

#### Ajuste Automatizado en macOS:
Puedes utilizar la herramienta nativa de macOS `sips` en la terminal para redimensionar tus capturas de forma instantánea sin perder calidad ni proporciones:

```bash
# Redimensionar para iPhone (6.7 pulgadas)
sips -z 2778 1284 captura_original.png --out iphone_1284x2778.png

# Redimensionar para iPad (12.9 pulgadas)
sips -z 2732 2048 captura_original.png --out ipad_2048x2732.png
```

---

### Paso 4: Política de Privacidad

App Store Connect exige una URL pública y válida con las políticas de privacidad de tu aplicación. 

#### Solución:
*   Creamos un archivo de texto descriptivo e internacional [PRIVACY.md](file:///Users/malva/Documents/projects/mobile/xIDE/PRIVACY.md) que declara que **xIDE no recopila datos de los usuarios** (ya que funciona de forma local y offline).
*   Subimos este archivo directamente a la raíz de tu repositorio de GitHub:
    ```bash
    git add PRIVACY.md
    git commit -m "Add Privacy Policy for App Store"
    git push origin main
    ```
*   La URL pública que debes configurar en la ficha de App Store Connect es el enlace del archivo en tu repositorio de GitHub:
    `https://github.com/holasoymalva/xIDE/blob/main/PRIVACY.md`

---

### Paso 5: Cumplimiento de Exportación y Encriptación (US Export Compliance)

Al seleccionar tu build compilado en App Store Connect, el sistema te preguntará sobre los algoritmos de encriptación de tu app debido a regulaciones comerciales de EE. UU.

*   **Respuesta Correcta**: Debes elegir **"Ninguno de los algoritmos mencionados anteriormente"**.
*   **Explicación**: xIDE no incorpora mecanismos criptográficos propietarios ni realiza transmisiones seguras fuera de las funciones estándar de HTTPS que utiliza el sistema operativo de Apple de manera nativa.

#### Automatización (Evitar que pregunte de nuevo):
Agrega la siguiente clave a tu archivo Info.plist o en la sección *Info* del Target en Xcode:
*   **Clave**: `ITSAppUsesNonExemptEncryption`
*   **Tipo**: Boolean (`Boolean`)
*   **Valor**: `NO`

---

### Paso 6: Compilación, Carga y Evitar Duplicaciones

1.  **Subir la App**: En Xcode selecciona el destino **Any iOS Device (arm64)**, ve a **Product** > **Archive** y en el Organizer haz clic en **Distribute App** > **Upload**.
2.  **Error de Compilación Duplicada**:
    > ❌ *Redundant Binary Upload. You've already uploaded a build with build number '2' for version number '1.0'.*
    *   **Solución**: Si necesitas subir una nueva compilación debido a cambios en el código, debes incrementar el campo **Build** en la configuración de Xcode (bajo la pestaña *General* > *Identity*). Por ejemplo, subir de `2` a `3`. La *Version* puede mantenerse en `1.0`.
3.  **Procesamiento**: Tras una subida exitosa, el build aparecerá en la pestaña **TestFlight** de App Store Connect en estado *"Procesando"*. Este proceso tarda aproximadamente 10 minutos. Una vez finalizado, puedes ir a la sección **Compilación** en la pestaña de la **Versión 1.0** y seleccionarla con el botón **+**.

---

Una vez completados todos estos pasos, haz clic en **Añadir a revisión** en App Store Connect. ¡Tu aplicación estará oficialmente en cola para ser aprobada y lanzada a la tienda!
