; Installateur Windows de CLEARANCE (NSIS 3, ARCHITECTURE §16.9).
; Construit par tools/package_windows.sh — ne pas appeler makensis à la main sans
; les définitions ci-dessous :
;   -DVERSION=1.0.0          version affichée (application/config/version)
;   -DVERSION_QUAD=1.0.0.0   version de fichier (4 nombres)
;   -DSRC_DIR=…              dossier extrait de CLEARANCE-<version>[-demo]-windows.zip
;   -DOUT_FILE=…             CLEARANCE-Setup-<version>.exe / CLEARANCE-Demo-Setup-<version>.exe
;   -DICON=…                 assets/icons/icon.ico
;   -DDEMO                   (facultatif) démo J1–J5
;
; Installation PAR UTILISATEUR, sans droits administrateur (pas d'invite UAC,
; exécutable non signé, D-070) : %LOCALAPPDATA%\Programs\CLEARANCE, désinstalleur
; enregistré dans HKCU (« Applications installées » / « Ajout/suppression de
; programmes »). Les sauvegardes (%APPDATA%\Godot\app_userdata\CLEARANCE) ne sont
; jamais touchées par la désinstallation.

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user

!ifdef DEMO
	!define APP_NAME "CLEARANCE Demo"
	!define EXE_NAME "CLEARANCE-Demo.exe"
	!define PCK_NAME "CLEARANCE-Demo.pck"
!else
	!define APP_NAME "CLEARANCE"
	!define EXE_NAME "CLEARANCE.exe"
	!define PCK_NAME "CLEARANCE.pck"
!endif
!define PUBLISHER "Studio CLEARANCE"
!define WEBSITE "https://clearance.cardormedia.com"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
!define APP_KEY "Software\${PUBLISHER}\${APP_NAME}"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "${APP_KEY}" "InstallDir"
BrandingText "${PUBLISHER} — ${APP_NAME} ${VERSION}"

VIProductVersion "${VERSION_QUAD}"
VIFileVersion "${VERSION_QUAD}"

!include "MUI2.nsh"
!include "FileFunc.nsh"

; --- Interface -------------------------------------------------------------------
!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_LANGDLL_REGISTRY_ROOT HKCU
!define MUI_LANGDLL_REGISTRY_KEY "${APP_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE_NAME}"
!define MUI_FINISHPAGE_LINK "${WEBSITE}"
!define MUI_FINISHPAGE_LINK_LOCATION "${WEBSITE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Première langue = défaut du sélecteur (le jeu est écrit en français, D-213).
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_RESERVEFILE_LANGDLL

; --- Métadonnées du .exe (Propriétés > Détails) ------------------------------------
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "© 2026 ${PUBLISHER}"

; --- Textes ------------------------------------------------------------------------
LangString SEC_GAME_NAME ${LANG_FRENCH} "${APP_NAME} (requis)"
LangString SEC_GAME_NAME ${LANG_ENGLISH} "${APP_NAME} (required)"
LangString SEC_GAME_DESC ${LANG_FRENCH} "Le jeu, ses crédits et ses licences."
LangString SEC_GAME_DESC ${LANG_ENGLISH} "The game, its credits and licenses."
LangString SEC_MENU_NAME ${LANG_FRENCH} "Raccourci dans le menu Démarrer"
LangString SEC_MENU_NAME ${LANG_ENGLISH} "Start menu shortcut"
LangString SEC_MENU_DESC ${LANG_FRENCH} "Ajoute ${APP_NAME} au menu Démarrer."
LangString SEC_MENU_DESC ${LANG_ENGLISH} "Adds ${APP_NAME} to the Start menu."
LangString SEC_DESK_NAME ${LANG_FRENCH} "Raccourci sur le Bureau"
LangString SEC_DESK_NAME ${LANG_ENGLISH} "Desktop shortcut"
LangString SEC_DESK_DESC ${LANG_FRENCH} "Ajoute une icône ${APP_NAME} sur le Bureau."
LangString SEC_DESK_DESC ${LANG_ENGLISH} "Adds a ${APP_NAME} icon to the desktop."
LangString UNINST_SAVES ${LANG_FRENCH} "Vos sauvegardes sont conservées (%APPDATA%\Godot\app_userdata\CLEARANCE)."
LangString UNINST_SAVES ${LANG_ENGLISH} "Your saves are kept (%APPDATA%\Godot\app_userdata\CLEARANCE)."

; --- Sections ----------------------------------------------------------------------
Section "!$(SEC_GAME_NAME)" SecGame
	SectionIn RO
	SetOutPath "$INSTDIR"
	; Mise à jour : on remplace les fichiers du jeu, le reste du dossier est intact.
	Delete "$INSTDIR\${EXE_NAME}"
	Delete "$INSTDIR\${PCK_NAME}"
	RMDir /r "$INSTDIR\licenses"
	File /r "${SRC_DIR}/*"
	WriteUninstaller "$INSTDIR\uninstall.exe"

	WriteRegStr HKCU "${APP_KEY}" "InstallDir" "$INSTDIR"
	WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
	WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
	WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${PUBLISHER}"
	WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${EXE_NAME},0"
	WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "${WEBSITE}"
	WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
	WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
	WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
	WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $0 "0x%08X" $0
	WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "$(SEC_MENU_NAME)" SecMenu
	CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${EXE_NAME}" 0
SectionEnd

Section "$(SEC_DESK_NAME)" SecDesktop
	CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${EXE_NAME}" 0
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SecGame} $(SEC_GAME_DESC)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecMenu} $(SEC_MENU_DESC)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} $(SEC_DESK_DESC)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function .onInit
	!insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

; --- Désinstallation -----------------------------------------------------------------
; Seuls les fichiers posés par l'installateur sont supprimés (jamais RMDir /r
; sur $INSTDIR : l'utilisateur a pu choisir un dossier partagé).
Section "Uninstall"
	Delete "$SMPROGRAMS\${APP_NAME}.lnk"
	Delete "$DESKTOP\${APP_NAME}.lnk"
	Delete "$INSTDIR\${EXE_NAME}"
	Delete "$INSTDIR\${PCK_NAME}"
	Delete "$INSTDIR\CREDITS.txt"
	RMDir /r "$INSTDIR\licenses"
	Delete "$INSTDIR\uninstall.exe"
	RMDir "$INSTDIR"
	DeleteRegKey HKCU "${UNINST_KEY}"
	DeleteRegKey HKCU "${APP_KEY}"
	DeleteRegKey /ifempty HKCU "Software\${PUBLISHER}"
	DetailPrint "$(UNINST_SAVES)"
SectionEnd

Function un.onInit
	!insertmacro MUI_UNGETLANGUAGE
FunctionEnd
