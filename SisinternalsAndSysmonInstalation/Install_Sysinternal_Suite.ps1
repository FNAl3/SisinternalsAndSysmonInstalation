# ==========================================
# Script de Instalación Automática de Sysmon
# ==========================================

# 1. Verificación de permisos de Administrador
# Agregamos CmdletBinding para soportar -WhatIf y -Confirm
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Warning "¡Alto! Necesitas ejecutar PowerShell como Administrador para instalar servicios."
    Break
}

# Configuración básica
$SystemDrive = $env:SystemDrive
$InstallPath = "$SystemDrive\Sysinternals"
$ConfigUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"
$ConfigName = "sysmonconfig-export.xml"
$SysmonServiceName = "Sysmon64" # Default for 64-bit, fallback to Sysmon

# Check architecture
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    $SysmonExeName = "Sysmon64.exe"
}
else {
    $SysmonExeName = "Sysmon.exe"
    $SysmonServiceName = "Sysmon"
}

# 2. Pre-chequeo: ¿Ya está instalado?
Write-Host "1. Verificando estado actual..." -ForegroundColor Cyan
if (Get-Service -Name $SysmonServiceName -ErrorAction SilentlyContinue) {
    Write-Host "   -> El servicio '$SysmonServiceName' ya está instalado y detectado." -ForegroundColor Green
    Write-Host "   -> No se realizarán cambios. Saliendo."
    Exit
}
else {
    Write-Host "   -> El servicio no está instalado. Continuando..."
}

# 3. Crear el directorio (si no existe)
if (-not (Test-Path -Path $InstallPath)) {
    if ($PSCmdlet.ShouldProcess($InstallPath, "Crear directorio")) {
        Write-Host "2. Creando directorio $InstallPath..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    }
}
else {
    Write-Host "2. El directorio $InstallPath ya existe." -ForegroundColor Gray
}

# 4. Descargar Sysinternals Suite (solo si faltan archivos clave)
if (-not (Test-Path "$InstallPath\$SysmonExeName")) {
    if ($PSCmdlet.ShouldProcess("$InstallPath", "Descargar y descomprimir Sysinternals Suite")) {
        Write-Host "3. Descargando Sysinternals Suite..." -ForegroundColor Cyan
        try {
            $ZipPath = "$InstallPath\SysinternalsSuite.zip"
            Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile $ZipPath
            
            Write-Host "   -> Descomprimiendo archivos..." -ForegroundColor Cyan
            Expand-Archive -Path $ZipPath -DestinationPath $InstallPath -Force
            Remove-Item $ZipPath -ErrorAction SilentlyContinue
        }
        catch {
            Write-Error "Error al descargar o descomprimir Sysinternals. Verifica tu conexión."
            Break
        }
    }
}
else {
    Write-Host "3. Archivos de Sysinternals ya presentes. Saltando descarga." -ForegroundColor Gray
}

# 5. Descargar/Actualizar configuración de SwiftOnSecurity
if ($PSCmdlet.ShouldProcess("$InstallPath\$ConfigName", "Descargar configuración SwiftOnSecurity")) {
    Write-Host "4. Descargando configuración recomendada (SwiftOnSecurity)..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $ConfigUrl -OutFile "$InstallPath\$ConfigName"
    }
    catch {
        Write-Warning "No se pudo descargar la configuración XML. Se intentará instalar sin config o usando la existente si la hay."
    }
}

# 6. Instalar Sysmon
Write-Host "5. Instalando servicio Sysmon ($SysmonExeName)..." -ForegroundColor Cyan
if (Test-Path $InstallPath) {
    Set-Location -Path $InstallPath
}

# Construir comando
if (Test-Path ".\$ConfigName") {
    $InstallArgs = "-accepteula -i $ConfigName"
}
else {
    Write-Warning "Archivo de configuración no encontrado. Instalando con configuración por defecto."
    $InstallArgs = "-accepteula -i"
}

if ($PSCmdlet.ShouldProcess("$SysmonExeName", "Ejecutar instalación con argumentos: $InstallArgs")) {
    try {
        # Ejecutar
        Start-Process -FilePath ".\$SysmonExeName" -ArgumentList $InstallArgs -Wait -NoNewWindow
    }
    catch {
        Write-Error "Ocurrió un error al intentar ejecutar el comando de instalación."
        Write-Error $_
    }
}

# 7. Verificación final
Write-Host "----------------------------------------"
if (Get-Service -Name $SysmonServiceName -ErrorAction SilentlyContinue) {
    Write-Host "¡ÉXITO! Sysmon está instalado y corriendo." -ForegroundColor Green
    Write-Host "Ruta de logs: Applications and Services Logs/Microsoft/Windows/Sysmon/Operational" -ForegroundColor Gray
}
else {
    Write-Host "Aviso: No se pudo verificar si el servicio arrancó inmediatamente. Puede requerir unos segundos o reinicio." -ForegroundColor Yellow
}
