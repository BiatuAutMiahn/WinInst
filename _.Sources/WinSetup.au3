#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Res\Infinity.ico
#AutoIt3Wrapper_Outfile_x64=..\InitSetup.exe
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Description=Unattended Windows Setup
#AutoIt3Wrapper_Res_Fileversion=1.0.0.34
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Fileversion_First_Increment=y
#AutoIt3Wrapper_Res_ProductName=Infinity.WinSetup
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/mo
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;AutoIt3Wrapper_Res_HiDpi=Y
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.16.1
 Author:         BiatuAutMiahn[@outlook.com]

 Script Function:
	Install windows


; AutoIt cannot currently handle uint64 integers, anything greater than 2147483647 (0x7fffffff)

[TODO]
[.] Prompt user for windows image if not found.
[.] Error Handling
[.] Logging
[.] Driver Install/Load
[.] Driver Install/Load UI
[.] Driver UI default if no physical disks
[#] Check Ram Mode
[#] Query Disk Info
[#] Find Install wim/esd
[#] Main UI
[#]     Layout
[#]     Dropdown
[#]     Progress
[#]     Reload
[#]     Install
[#]     Reboot
[#] Diskpart Wrap
[#]     STDOUT
[#]         Handle Feedback
[#]     STDIN
[#]     Script
[#]         Clear disk
[#]         Create partitions (ESD:512MB,MSR:128MB,WIN,REC:1024MB)
[#] Wimlib Wrap
[#]     STDOUT
[#]         Parse Progress
[#] Copy Boot Files
[#] Configure BCD
[#] Copy WinRE Files
[#] Configure WinRE
[#] Update UEFI Boot Entry
[#] Reboot Prompt /w Timeout
#ce ----------------------------------------------------------------------------

;Opt("ExpandEnvStrings",1)

#include <Array.au3>
#include <String.au3>
#include <WinAPIFiles.au3>
#include <WinAPIProc.au3>
#include <APIFilesConstants.au3>
#include <WinAPIConv.au3>
#include <GuiMenu.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <GUIConstantsEx.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <GuiButton.au3>
#include <GuiImageList.au3>
#include <WinAPIShellEx.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <WinAPIShellEx.au3>
#include <WinAPIProc.au3>
#include <ProcessConstants.au3>
#include <WinAPISys.au3>

#include "Includes\ProcessEx.au3"
#include "Includes\ModernMenuRaw.au3"
#include "Includes\ArrayNaturalSort.au3"


;DllCall("Kernel32.dll", "bool", "AllocConsole")
;_WinAPI_AttachConsole(-1)
; Global Const
Global Const $VERSION = "1.0.0.34"
Global Const $sAlias = "Infinity.WinInst"
Global $sGuiTitle = $sAlias & " v" & $VERSION & 'b'
Global Const $wbemFlagReturnImmediately = 0x10
Global Const $wbemFlagForwardOnly = 0x20
Global Const $iWbemFlags = $wbemFlagReturnImmediately;+$wbemFlagForwardOnly
Global Const $iSizeMBytes = 1024 * 1024
Global Const $iSizePartEfi = 512 * $iSizeMBytes
Global Const $iSizePartMsr = 128 * $iSizeMBytes
Global Const $iSizePartRec = 1024 * $iSizeMBytes
Global Const $aMui = StringSplit("bg-BG|cs-CZ|da-DK|de-DE|el-GR|en-GB|en-US|es-ES|es-MX|et-EE|fi-FI|fr-CA|fr-FR|hr-HR|hu-HU|it-IT|ja-JP|ko-KR|lt-LT|lv-LV|nb-NO|nl-NL|pl-PL|pt-BR|pt-PT|qps-ploc|ro-RO|ru-RU|sk-SK|sl-SI|sr-Latn-RS|sv-SE|tr-TR|uk-UA|zh-CN|zh-TW", '|')
;$__eDPIAWARNESS_Process_DPI_Unaware = 0
;$__eDPIAWARNESS_Process_System_DPI_Aware = 1
;$__eDPIAWARNESS_Process_Per_Monitor_DPI_Aware = 2

; Global Flags
Global $sDataDir=@Compiled?@ScriptDir:@ScriptDir&"\.."
Global $bRamMode = False
Global $bUsage = False
Global $bSim = StringInStr($CmdLineRaw,"~!dryrun")
;MsgBox(64,$bSim,$CmdLineRaw)
If $bSim Then
    $sGuiTitle&=" (Sim)"
EndIf
; Global Vars
Global $sWimPath
Global $oWmiSmp
Global $oWmiRoot
Global $iDrive
Global $iLongestName = 0
Global $aDisks[0][3]
Global $aWims[1][2]
Global $aWimImages

;Global Const $aWmiDiskFields = StringSplit("Index|InterfaceType|Model|DeviceID|Size",'|',0); |GUID

_Log($sGuiTitle&@CRLF)
; Pre Drive Check.
;_DrvChk()

_Log("Initializing SMP...")
Local $oWmiSmp = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
Global $oDisks = $oWmiSmp.ExecQuery('SELECT * FROM MSFT_Disk', "WQL", $iWbemFlags)
If Not IsObj($oDisks) Then
	_Log("Error: Failed to initialize Windows SMP Interface.")
	Exit 1
EndIf
_Log("Done"&@CRLF)

_Log("Initializing UI...")
#Region ### MainGUI ###
AutoItSetOption("GUIOnEventMode", 1)
Global $iGuiW = 640 - (640 / 4)
Global $iGuiH = 238
Global $iComCtrlH = 16
Global $iBtnH = 28
Global $iBtnT = 208
Global $agidOpt[2]
Global $agsBtn = StringSplit("&Pause,&Resume,&Install,&Abort,&Tools,&Quit", ',')
Global $agidBtn[$agsBtn[0]+1]
Global $iComCtrlW = $iGuiW - 8
Global $iBtnW = $iComCtrlW/($agsBtn[0]-2);-($agsBtn[0]-3)*2
;Global $agsBtn = StringSplit("&Pause,&Resume,&Install,&Abort,&Tools,&Quit", ',')
Global $iGuiState = 0
Global $iGuiOptState = 0
Global $iGuiLastState = 0
Global $iGuiOptLastState = 0
Global $iWims = 0
Global $iWimIdx = -1
Global $iDisks = 0
Global $iDisk = -1
Global $iSetupStage = -1
Global $gsProgLblStp = ""
Global $bAbort = False
Global $bAbortExit = False
Global $bPause = False
Global $iFileTot = 0
Global $iFileCur = 0
Global $iTotMax = 359
Global $oDisk
;Global $bOptUnattend = False
Global $bOptAutoReboot = False
Global $_WndTimeoutMsg
Global $_WndTimeoutTimer
Global $_WndTimeoutTimerLast
Global $_WndTimeoutTimeout
Global $_WndTimeoutCallback
Global $_WndTimeoutMsgLast
Global $iWimLibPid
Global $hWimLibProc
Global $hBtnImgList
Global $hUtilImgList
Global $aUtils[1][11]; sName, sVersion, sDescription, sIcon, iIconIndex, sCmd, $sDefParams; idCtrl, sPath
;_WinAPI_SetProcessDPIAwareness($__eDPIAWARNESS_Process_DPI_Unaware)

$aUtils[0][0]=0
;_GUICtrlMenuEx_Startup()
;_FindImage()
;_Log("WimPath:"&$sWimPath & @CRLF)
$agidBtn[0] = $agsBtn[0]
$agidOpt[0] = 1
$hMain = GUICreate($sGuiTitle, $iGuiW, $iGuiH, -1, -1, 0x16CE0000, 0x00010100)
GUISetFont(10, 400, 0, "Consolas", $hMain)
$gidDisk = GUICtrlCreateCombo("Scanning...", 4, 4, $iComCtrlW - 60 - 4, 24, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
GUICtrlSetOnEvent($gidDisk, "_GuiEvtButton")
$gidDiskScan = GUICtrlCreateButton("Rescan", $iComCtrlW - 58, 3, 64, 25)
GUICtrlSetOnEvent($gidDiskScan, "_GuiEvtButton")
$ghDisks = GUICtrlGetHandle($gidDisk)
$gidWim = GUICtrlCreateCombo("No Disk Selected.", 4, 32, $iComCtrlW - 60 - 4, 3, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
GUICtrlSetOnEvent($gidWim, "_GuiEvtButton")
$gidWimSel = GUICtrlCreateButton("Browse", $iComCtrlW - 58, 31, 64, 25)
GUICtrlSetOnEvent($gidWimSel, "_GuiEvtButton")
$ghWim = GUICtrlGetHandle($gidWim)
$gidWimIdx = GUICtrlCreateCombo("No Disk Selected.", 4, 60, $iComCtrlW, 3, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
GUICtrlSetOnEvent($gidWimIdx, "_GuiEvtButton")
$ghWimIdx = GUICtrlGetHandle($gidWimIdx)

;GUICtrlSetFont($gidDiskScan,16,400,0,"Webdings")
;$agidOpt[1] = GUICtrlCreateCheckbox("Unattend.xml /w Utils", 4, 32, 128 + 32 + 4, $iComCtrlH)
;GUICtrlSetOnEvent($agidOpt[1], "_GuiEvtOpt")
$agidOpt[1] = GUICtrlCreateCheckbox("Auto Reboot", 4, 90, 64 + 16 + 8 + 4 + 2, $iComCtrlH)
GUICtrlSetOnEvent($agidOpt[1], "_GuiEvtOpt")
$gidLabelStp = GUICtrlCreateLabel("Waiting", 4, 108, $iComCtrlW, $iComCtrlH)
$gidProgStp = GUICtrlCreateProgress(4, 124, $iComCtrlW, $iComCtrlH, $PBS_SMOOTH)
$ghProgStp = GUICtrlGetHandle($gidProgStp)
$gidLabelStg = GUICtrlCreateLabel("Waiting", 4, 140, $iComCtrlW, $iComCtrlH)
$gidProgStg = GUICtrlCreateProgress(4, 156, $iComCtrlW, $iComCtrlH, $PBS_SMOOTH)
$ghProgStg = GUICtrlGetHandle($gidLabelStg)
$gidLabelTot = GUICtrlCreateLabel("Total Progress", 4, 172, $iComCtrlW, $iComCtrlH)
$gidProgTot = GUICtrlCreateProgress(4, 188, $iComCtrlW, $iComCtrlH, $PBS_SMOOTH)
$ghProgTot = GUICtrlGetHandle($gidProgTot)
$igBtnL = 4;4 + ($iComCtrlW / 2) - (($iBtnW / 2) * ($agidBtn[0] - 2)) ;-(($iBtnW+4)*$agidBtn[0])/2
;$igBtnW =
$agidBtn[1] = GUICtrlCreateButton($agsBtn[1], $igBtnL, $iBtnT, $iBtnW, 28)
$agidBtn[2] = GUICtrlCreateButton($agsBtn[2], $igBtnL, $iBtnT, $iBtnW, 28)
$hBtnImgList = _GUIImageList_Create(16, 16, 5, 0, 1)
_GUIImageList_AddIcon($hBtnImgList,@SystemDir & '\comdlg32.dll',16)
For $i = 3 To $agidBtn[0]
	If $i > $agidBtn[0] - 2 Then
		$agidBtn[$i] = GUICtrlCreateButton($agsBtn[$i], ($igBtnL) + ($iBtnW * ($i - 3)), $iBtnT, $iBtnW, $iBtnH, $BS_SPLITBUTTON)
		_GUICtrlButton_SetSplitInfo(GUICtrlGetHandle($agidBtn[$i]), $hBtnImgList, $BCSS_IMAGE)
	Else
		$agidBtn[$i] = GUICtrlCreateButton($agsBtn[$i], ($igBtnL) + ($iBtnW * ($i - 3)), $iBtnT, $iBtnW, $iBtnH)
	EndIf
Next
For $i = 1 To $agidBtn[0]
	GUICtrlSetOnEvent($agidBtn[$i], "_GuiEvtButton")
Next
GUISetOnEvent($GUI_EVENT_CLOSE, "_GuiEvtClose")

; Exit Menu
Local $idExitMenuDummy = GUICtrlCreateDummy()
Local $idExitMenu = GUICtrlCreateContextMenu($idExitMenuDummy)
$gidExitMenuExit=GUICtrlCreateMenuItem("Exit", $idExitMenu)
GUICtrlCreateMenuItem("", $idExitMenu)
$gidExitMenuShut=GUICtrlCreateMenuItem("Shutdown", $idExitMenu)
$gidExitMenuRebt=GUICtrlCreateMenuItem("Reboot", $idExitMenu)
GUICtrlSetOnEvent($gidExitMenuExit, "_GuiEvtButton")
GUICtrlSetOnEvent($gidExitMenuShut, "_GuiEvtButton")
GUICtrlSetOnEvent($gidExitMenuRebt, "_GuiEvtButton")
; Initial States
_GuiCtrlState(0)   ; Opts
_GuiCtrlState(0,1) ; Combos
_GuiCtrlState(0,2) ; Btns
_GuiState(0)

; Build Utils Menu
Local $idUtilMenuDummy = GUICtrlCreateDummy()
Local $idUtilMenu = GUICtrlCreateContextMenu($idUtilMenuDummy)
Local $ghUtilMenu = GUICtrlGetHandle($idUtilMenu)
Local $gsUtilDir=_WinAPI_ExpandEnvironmentStrings("%SystemDrive%\System\Programs")
Local $aInfProgList=_FileListToArrayRec($gsUtilDir,"_.mkBundle.ini",1,1,1)
Local $sSection="Infinity.Program"
Local $aSectKeys=StringSplit("Name|Version|Icon|IconIndex|Cmd|DefParams|Description",'|')
$hUtilImgList = _GUIImageList_Create(16, 16, 5, 0, 1)
If IsArray($aInfProgList) Then
    For $i=1 To $aInfProgList[0]
        ;Dim $aProgInfo[$aSectKeys[0]+1]
        ;_Log($aInfProgList[$i]&@CRLF)
        ;_Log(&@CRLF)
        $iMax=UBound($aUtils,1)
        ReDim $aUtils[$iMax+1][11]
        $aUtils[$iMax][1]=StringLeft($aInfProgList[$i],StringInStr($aInfProgList[$i],'\',0,-1)-1); sPath
        For $j=1 To $aSectKeys[0]
            $aUtils[$iMax][2+($j-1)]=_WinAPI_ExpandEnvironmentStrings(IniRead($gsUtilDir&"\"&$aInfProgList[$i],$sSection,$aSectKeys[$j],''))
        Next
    Next
    $aUtils[0][0]=$iMax
    ;_ArrayDisplay($aUtils)
    _ArraySortEx($aUtils,0,1,0,2)
    _SetMenuBkColor(_WinAPI_GetSysColor($COLOR_MENU))
    _SetMenuIconBkColor(_WinAPI_GetSysColor($COLOR_MENU))
    ;_ArrayDisplay($aUtils)
    For $i=1 To $aUtils[0][0]
        $aUtils[$i][0]=_GUICtrlCreateODMenuItem($aUtils[$i][2]&" v"&$aUtils[$i][3],$idUtilMenu,$gsUtilDir&'\'&$aUtils[$i][1]&'\'&$aUtils[$i][4],$aUtils[$i][5])
        GUICtrlSetOnEvent($aUtils[$i][0],"_GuiEvtButton")
    Next
Else
    GUICtrlCreateMenuItem("No Utilities Found", $idUtilMenu)
EndIf

; Default States
GUIRegisterMsg($WM_COMMAND,"WM_COMMAND")
GUIRegisterMsg($WM_NOTIFY,"WM_NOTIFY")
GUIRegisterMsg($WM_MENUSELECT,"WM_MENUSELECT")
;_GuiCtrlState(2, 1); Buttons
;_GuiCtrlState(8, 2) ; Install Visible
;_GuiCtrlState(4); Rescan Visible
;_GuiCtrlState(16)

_Log("Done"&@CRLF)
GUISetState(@SW_SHOW,$hMain)
WinActivate($hMain)
;_RefreshDisks()
;_InitTimeout("Unattended Install","_AutoInstall")
;_GuiState(1)

#EndRegion ### MainGUI ###

While Sleep(1)
WEnd

Func WM_MENUSELECT($hWnd,$iMsg,$iwParam,$ilParam )
  Local $idMenu=BitAND($iwParam,0xFFFF )
  If $aUtils[0][0]=0 Then Return $GUI_RUNDEFMSG
  If $idMenu>=$aUtils[1][0] And $idMenu<=$aUtils[$aUtils[0][0]][0] Then
    Local $sTip=$aUtils[$idMenu-$aUtils[1][0]+1][8]
    ToolTip($sTip)
  Else
    ToolTip("")
  EndIf
  Return $GUI_RUNDEFMSG
EndFunc

Func MenuItem_SetIcon($s_FilePath, $i_IconID, $h_Menu, $i_MenuID, $i_Load = 0, $iW = 16, $iH = 16)
    Local $h_Module = 0

    ; check if ico file was passed
    if StringRight($s_FilePath, 4) <> '.exe' And StringRight($s_FilePath, 4) <> '.dll' then
        $i_IconID = $s_FilePath
        $i_Load = $LR_LOADFROMFILE
    Else ; exe or dll
        $h_Module = _WinAPI_GetModuleHandle($s_FilePath)
        if @error then MsgBox(0,'', '_WinAPI_GetModuleHandle')
    EndIf

    Local $h_Icon = _WinAPI_LoadImage($h_Module, $i_IconID, $IMAGE_ICON, $iW, $iH, $i_Load)

    if not $h_Icon then
        MsgBox(0,'_WinAPI_GetModuleHandle', _WinAPI_GetLastErrorMessage())
        Return
    EndIf

    Local $h_Bitmap = _GDIPlus_BitmapCreateFromHICON32($h_Icon)
    if @error then MsgBox(0,@extended, '_GDIPlus_BitmapCreateFromHICON32')
    Local $h_GDIBITMAP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($h_Bitmap)
    if @error then MsgBox(0,'', '_GDIPlus_BitmapCreateHBITMAPFromBitmap')

    _GUICtrlMenu_SetItemBmp(GUICtrlGetHandle($h_Menu), $i_MenuID, $h_GDIBITMAP, False)
    if @error then MsgBox(0,'', '_GUICtrlMenu_SetItemBmp')
    _WinAPI_DestroyIcon($h_Icon)
    _GDIPlus_ImageDispose($h_Bitmap)
EndFunc   ;==>MenuItem_SetIcon

Func _CreateBitmapFromIcon($iBackground, $sIcon, $iIndex, $iWidth, $iHeight)

    Local $hDC, $hBackDC, $hBackSv, $hIcon, $hBitmap

    $hDC = _WinAPI_GetDC(0)
    $hBackDC = _WinAPI_CreateCompatibleDC($hDC)
    $hBitmap = _WinAPI_CreateSolidBitmap(0, $iBackground, $iWidth, $iHeight)
    $hBackSv = _WinAPI_SelectObject($hBackDC, $hBitmap)
    $hIcon = _WinAPI_PrivateExtractIcon($sIcon, $iIndex, $iWidth, $iHeight)
    If Not @error Then
        _WinAPI_DrawIconEx($hBackDC, 0, 0, $hIcon, 0, 0, 0, 0, $DI_NORMAL)
        _WinAPI_DestroyIcon($hIcon)
    EndIf
    _WinAPI_SelectObject($hBackDC, $hBackSv)
    _WinAPI_ReleaseDC(0, $hDC)
    _WinAPI_DeleteDC($hBackDC)
    Return $hBitmap
EndFunc   ;==>_CreateBitmapFromIcon

Func _WinAPI_PrivateExtractIcon($sIcon, $iIndex, $iWidth, $iHeight)

    Local $hIcon, $tIcon = DllStructCreate('hwnd'), $tID = DllStructCreate('hwnd')
    Local $Ret = DllCall('user32.dll', 'int', 'PrivateExtractIcons', 'str', $sIcon, 'int', $iIndex, 'int', $iWidth, 'int', $iHeight, 'ptr', DllStructGetPtr($tIcon), 'ptr', DllStructGetPtr($tID), 'int', 1, 'int', 0)

    If (@error) Or ($Ret[0] = 0) Then
        Return SetError(1, 0, 0)
    EndIf
    $hIcon = DllStructGetData($tIcon, 1)
    If ($hIcon = Ptr(0)) Or (Not IsPtr($hIcon)) Then
        Return SetError(1, 0, 0)
    EndIf
    Return $hIcon
EndFunc   ;==>_WinAPI_PrivateExtractIcon

;https://www.autoitscript.com/forum/topic/208446-_arraysortex/
Func _ArraySortEx(ByRef $aArray, $iDescending = 0, $iStart = 0, $iEnd = 0, $iSubItem = 0, $iType = 2)
    If $iDescending = Default Then $iDescending = 0
    If $iStart = Default Then $iStart = 0
    If $iEnd = Default Then $iEnd = 0
    If $iSubItem = Default Then $iSubItem = 0
    If $iType = Default Then $iType = 2 ; 0 = string sort, 1 = numeric sort, 2 = natural sort

    If Not IsArray($aArray) Then Return SetError(1, 0, 0)

    Local $iDims = UBound($aArray, $UBOUND_DIMENSIONS)
    If $iDims < 1 Or $iDims > 2 Then Return SetError(4, 0, 0)

    Local $iRows = UBound($aArray, $UBOUND_ROWS)
    If $iRows = 0 Then Return SetError(5, 0, 0)

    Local $iCols = UBound($aArray, $UBOUND_COLUMNS) ; always 0 for 1D array
    If $iDims = 2 And $iSubItem > $iCols - 1 Then Return SetError(3, 0, 0)

    If $iType < 0 Or $iType > 2 Then Return SetError(6, 0, 0)

    ; Bounds checking
    If $iStart < 0 Then $iStart = 0
    If $iEnd <= 0 Or $iEnd > $iRows - 1 Then $iEnd = $iRows - 1
    If $iStart > $iEnd Then Return SetError(2, 0, 0)

    Local $tIndex = DllStructCreate("uint[" & ($iEnd - $iStart + 1) & "]")
    Local $pIndex = DllStructGetPtr($tIndex)
    Local $hDll = DllOpen("kernel32.dll")
    Local $hDllComp = DllOpen("shlwapi.dll")
    Local $lo, $hi, $mi, $r, $nVal1, $nVal2

    For $i = 1 To $iEnd - $iStart
        $lo = 0
        $hi = $i - 1
        If $iDims = 1 Then ; 1D
            Do
                $mi = Int(($lo + $hi) / 2)
                Switch $iType
                    Case 2 ; Natural Sort
                        $r = DllCall($hDllComp, 'int', 'StrCmpLogicalW', 'wstr', String($aArray[$i + $iStart]), _
                            'wstr', String($aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart]))[0]
                    Case 1 ; Numeric Sort
                        $nVal1 = Number($aArray[$i + $iStart])
                        $nVal2 = Number($aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart])
                        $r = $nVal1 < $nVal2 ? -1 : $nVal1 > $nVal2 ? 1 : 0
                    Case Else ; 0 = String Sort
                        $r = StringCompare($aArray[$i + $iStart], $aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart])
                EndSwitch

                Switch $r
                    Case -1
                        $hi = $mi - 1
                    Case 1
                        $lo = $mi + 1
                    Case 0
                        ExitLoop
                EndSwitch
            Until $lo > $hi
        Else ; 2D
            Do
                $mi = Int(($lo + $hi) / 2)
                Switch $iType
                    Case 2 ; Natural Sort
                        $r = DllCall($hDllComp, 'int', 'StrCmpLogicalW', 'wstr', String($aArray[$i + $iStart][$iSubItem]), _
                            'wstr', String($aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart][$iSubItem]))[0]
                    Case 1 ; Numeric Sort
                        $nVal1 = Number($aArray[$i + $iStart][$iSubItem])
                        $nVal2 = Number($aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart][$iSubItem])
                        $r = $nVal1 < $nVal2 ? -1 : $nVal1 > $nVal2 ? 1 : 0
                    Case Else ; 0 = String Sort
                        $r = StringCompare($aArray[$i + $iStart][$iSubItem], _
                            $aArray[DllStructGetData($tIndex, 1, $mi + 1) + $iStart][$iSubItem])
                EndSwitch

                Switch $r
                    Case -1
                        $hi = $mi - 1
                    Case 1
                        $lo = $mi + 1
                    Case 0
                        ExitLoop
                EndSwitch
            Until $lo > $hi
        EndIf

        DllCall($hDll, "none", "RtlMoveMemory", "struct*", $pIndex + ($mi + 1) * 4, _
            "struct*", $pIndex + $mi * 4, "ulong_ptr", ($i - $mi) * 4)
        DllStructSetData($tIndex, 1, $i, $mi + 1 + ($lo = $mi + 1))
    Next

    Local $aBackup = $aArray

    If $iDims = 1 Then ; 1D
        If Not $iDescending Then
            For $i = 0 To $iEnd - $iStart
                $aArray[$i + $iStart] = $aBackup[DllStructGetData($tIndex, 1, $i + 1) + $iStart]
            Next
        Else ; descending
            For $i = 0 To $iEnd - $iStart
                $aArray[$iEnd - $i] = $aBackup[DllStructGetData($tIndex, 1, $i + 1) + $iStart]
            Next
        EndIf
    Else ; 2D
        Local $iIndex
        If Not $iDescending Then
            For $i = 0 To $iEnd - $iStart
                $iIndex = DllStructGetData($tIndex, 1, $i + 1) + $iStart
                For $j = 0 To $iCols - 1
                    $aArray[$i + $iStart][$j] = $aBackup[$iIndex][$j]
                Next
            Next
        Else ; descending
            For $i = 0 To $iEnd - $iStart
                $iIndex = DllStructGetData($tIndex, 1, $i + 1) + $iStart
                For $j = 0 To $iCols - 1
                    $aArray[$iEnd - $i][$j] = $aBackup[$iIndex][$j]
                Next
            Next
        EndIf
    EndIf

    $tIndex = 0
    DllClose($hDll)
    DllClose($hDllComp)

    Return 1
EndFunc   ;==>_ArraySortEx

Func _Exit($iCode=0,$iShutdown=0)
    If $bPause Then _ProcessResume($hWimLibProc)
	_WinAPI_TerminateProcess($hWimLibProc)
	_WinAPI_WaitForSingleObject($hWimLibProc)
    If $iShutdown Then
         Shutdown($iShutdown)
    EndIf
	Exit $iCode
EndFunc   ;==>_Exit

Func _AutoInstall()
	_GuiState(1)
	_SelDisk(0)
	$iSetupStage = 0
	AdlibRegister("_InitInstall",1)
	_GuiState(3)
EndFunc   ;==>_AutoInstall

Func _TimerSleep($iDelay)
	Local $hTimer = TimerInit()
	While Sleep(0)
		If TimerDiff($hTimer) >= $iDelay Then Return
	WEnd
EndFunc   ;==>_TimerSleep

; Only way to set progress quickly
; otherwise an animation occurs that literally takes 250ms.
Func _SetProgress($idCtrl, $iProg)
	If $iProg = 100 Then
		GUICtrlSetData($idCtrl, 100)
        _TimerSleep(1)
		GUICtrlSetData($idCtrl, 99)
		GUICtrlSetData($idCtrl, 100)
	Else
		GUICtrlSetData($idCtrl, $iProg + 1)
		GUICtrlSetData($idCtrl, $iProg)
	EndIf
EndFunc   ;==>_SetProgress

Func _AbortInstall()
	$bAbort = False
	$iRet = MsgBox(48 + 1, $sGuiTitle, StringFormat("WARNING: if you abort the installation, the system will be left in an inconcistent state and may fail to boot!\n\nAre you certain you want to Abort the installation?"))
	If $iRet <> 1 Then Return 0
	If $bPause Then _ProcessResume($hWimLibProc)
	$bPause = False
	_WinAPI_TerminateProcess($hWimLibProc)
	_WinAPI_WaitForSingleObject($hWimLibProc)
    If $bAbortExit Then
        _Exit()
    EndIf
	$iSetupStage = -1
    ;GUICtrlSetData($gidLabelStp,"Waiting")
    ;GUICtrlSetData($gidLabelStg,"Waiting")
    ;DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($gidProgStp), "wstr", 0, "wstr", 0)
    ;GUICtrlSetStyle($gidProgStp, BitOr($GUI_SS_DEFAULT_PROGRESS, $PBS_SMOOTH))
    _SendMessage($ghProgStp, $PBM_SETSTATE, 2) ; red
    _SendMessage($ghProgStg, $PBM_SETSTATE, 2)
    _SendMessage($ghProgTot, $PBM_SETSTATE, 2)
	GUICtrlSetData($gidLabelTot, 'Installation Aborted')
	_GuiState(8)
	Return 1
EndFunc   ;==>_AbortInstall

Func _AutoReboot()
    $iSetupStage = -1
    _GuiState(6)
	_Exit(0,2)
EndFunc   ;==>_AutoReboot

Func _ProcessSuspend($hProcess)
	Local $aSuspend = DllCall("ntdll.dll", "int", "NtSuspendProcess", "int", $hProcess)
	If IsArray($aSuspend) Then Return 1
	SetError(1)
	Return 0
EndFunc   ;==>_ProcessSuspend

Func _ProcessResume($hProcess)
	Local $aResume = DllCall("ntdll.dll", "int", "NtResumeProcess", "int", $hProcess)
	If IsArray($aResume) Then Return 1
	SetError(1)
	Return 0
EndFunc   ;==>_ProcessResume

Func _InstallInterrupt()
	If $bAbort Then
		If _AbortInstall() Then Return 1
	EndIf
	If $bPause Then
		While Sleep(10)
            If Not $bPause Then ExitLoop
            If $bAbort Then
                If _AbortInstall() Then Return 1
            EndIf
		WEnd
	EndIf
EndFunc   ;==>_InstallInterrupt

Func _InitInstall()
	AdlibUnRegister("_InitInstall")
;~     If $bAbort Then
;~         If _AbortInstall() Then Return
;~     EndIf
;~     Return AdlibRegister("_InitInstall",1)
    ;Return $GUI_RUNDEFMSG
	If _InstallInterrupt() Then Return
	Local $areMatch[] = [ _
			"Creating files: (\d+) of (\d+) \((\d{1,3})%\) done", _
			"Extracting file data: (\d+) ((?:B|[A-Z]iB)) of (\d+) ((?:B|[A-Z]iB)) \((\d{1,3})%\) done", _
			"Applying metadata to files: (\d+) of (\d+) \((\d{1,3})%\) done" _
    ]
    Local $iStgTot=5
    Local $sStrFmtStg=StringFormat("Stage (%%d/%d) %%s",$iStgTot)
    Local $sStrFmtStp=StringFormat("Step (%%%%d/%%d) %%%%s")
    Local $iStepTot
	Switch $iSetupStage
		; Initializing Disk
        Case 0 ; Clear Partition Table
            $iStepTot=9
            $sStrFmtStp=StringFormat($sStrFmtStp,$iStepTot)
			GUICtrlSetData($gidLabelTot, 'Total Progress')
			GUICtrlSetData($gidLabelStg, StringFormat($sStrFmtStg,$iSetupStage+1,"Preparing Disk"))
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,1,"Clearing Partition Table"))
			_SetProgress($gidProgStp, 0)
			_SetProgress($gidProgStg, 0)
			If _InstallInterrupt() Then Return
			If Not $bSim Then $oDisk.Clear(1, 1)
            _TimerSleep(125)
			_SetProgress($gidProgStg, (1/$iStepTot)*100)
			_TimerSleep(1)
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,2,"Initializing GPT Partition Table"))
			If _InstallInterrupt() Then Return
			If Not $bSim Then $oDisk.Initialize(2)
            _TimerSleep(125)
			If Not $bSim Then $oDisk.Refresh()
            _TimerSleep(125)
            $oParts = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Partition WHERE DiskNumber = " & $oDisk.Number)
            For $oPart In $oParts
                $oPart.DeleteObject()
            Next
            _TimerSleep(125)
			_SetProgress($gidProgStp, (2 / $iStepTot) * 100)
			_TimerSleep(1)
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,3,"Creating EFI Partition"))
			If _InstallInterrupt() Then Return
			If Not $bSim Then $iRet = $oDisk.CreatePartition($iSizePartEfi, Null, Null, Null, 'T', Null, Null, "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}")
            _TimerSleep(125)
			;If $iRet<>0 Then Failure
			_SetProgress($gidProgStp, (3 / $iStepTot) * 100)
			_TimerSleep(1)
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,4,"Creating MSR Partition"))
			If _InstallInterrupt() Then Return
			If Not $bSim Then $oDisk.CreatePartition($iSizePartMsr, Null, Null, Null, Null, Null, Null, "{e3c9e316-0b5c-4db8-817d-f92df00215ae}")
            _TimerSleep(125)
			;If $iRet<>0 Then Failure
			_SetProgress($gidProgStp, (4 / $iStepTot) * 100)
			_TimerSleep(1)
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,5,"Creating Windows Partition"))
			If _InstallInterrupt() Then Return
			If Not $bSim Then $oDisk.CreatePartition(String($oDisk.Size - $iSizePartEfi - $iSizePartMsr - $iSizePartRec - (2 * $iSizeMBytes)), Null, Null, Null, 'U')
            _TimerSleep(125)
			;If $iRet<>0 Then Failure
			_SetProgress($gidProgStp, (5 / $iStepTot) * 100)
			_TimerSleep(1)
			GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,6,"Creating Recovery Partition"))
			If _InstallInterrupt() Then Return
			If Not $bSim Then $oDisk.CreatePartition($iSizePartRec, Null, Null, Null, 'V', Null, Null, "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}")
			;If $iRet<>0 Then Failure
			If Not $bSim Then $oDisk.Refresh()
            _TimerSleep(125)
			_SetProgress($gidProgStp, (6 / $iStepTot) * 100)
			_TimerSleep(1)
			If _InstallInterrupt() Then Return
			$oParts = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Partition WHERE DiskNumber = " & $oDisk.Number)
			;If Not IsObj($oParts) Then Failed
			Local $aiTmpProg = 6
			For $oPart In $oParts
				If _InstallInterrupt() Then Return
				$oVolumes = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Volume")
				For $oVol In $oVolumes
					If _InstallInterrupt() Then Return
					If $oVol.DriveLetter <> $oPart.DriveLetter Then ContinueLoop
					$sLetter = Chr($oVol.DriveLetter)
					_SetProgress($gidProgStp, ($aiTmpProg / $iStepTot) * 100)
					_SetProgress($gidProgStp, ($aiTmpProg / $iStepTot) * 100)
					Switch $oPart.GptType
						Case "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
							GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,$aiTmpProg+1,"Formatting EFI Partition"))
							If Not $bSim Then $iRet = $oVol.Format("FAT32", Null, Null, False, True)
                            _TimerSleep(125)
							;If $iRet<>0 Then
						Case "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
							GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,$aiTmpProg+1,"Formatting Windows Partition"))
							If Not $bSim Then $iRet = $oVol.Format("NTFS", Null, Null, False, True)
                            _TimerSleep(125)
							;If $iRet<>0 Then
						Case "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
							GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,$aiTmpProg+1,"Formatting Recovery Partition"))
							If Not $bSim Then $iRet = $oVol.Format("NTFS", Null, Null, False, True)
                            _TimerSleep(125)
							;If $iRet<>0 Then
					EndSwitch
					$aiTmpProg += 1
					_SetProgress($gidProgStp, ($aiTmpProg / 3) * 100)
					_SetProgress($gidProgTot, ($aiTmpProg / $iTotMax) * 100)
					_TimerSleep(1)
				Next
			Next
			_SetProgress($gidProgStp, 100)
			_SetProgress($gidProgStg, (($iSetupStage+1)/$iStgTot)*100)
			_SetProgress($gidProgTot, ($iStepTot/$iTotMax) * 100)
			_TimerSleep(1)
            _IncStage()
		Case 1 ; Applying Windows Image
			GUICtrlSetData($gidLabelStg, StringFormat($sStrFmtStg,$iSetupStage+1,"Applying Windows Image"))
			_SetProgress($gidProgStp, 0)
            $sCmdLine='"' & $sDataDir & '\InfinitySys\bin\wimlib-imagex.exe" apply ' & (StringInStr($sWimPath, ' ') <> 0 ? '"' & $sWimPath & '"' : $sWimPath) & ' '&($iWimIdx+1)&' U:\'
            _Log($sCmdLine&@CRLF)
            If $bSim Then Return _IncStage()
			$iWimLibPid = Run($sCmdLine, $sDataDir, @SW_HIDE, 0x6)
            _TimerSleep(125)
            ;$iWimLibPid=-1
			$hWimLibProc = _WinAPI_OpenProcess($PROCESS_ALL_ACCESS, 0, $iWimLibPid)
			;If Not $iPid Then Failed
			Local $sStdErr = ''
			Local $sStdOut = ''
			Local $vReadOut, $vReadErr
			Local $iErrOut, $iErrErr
            $iStepTot=3
            $sStrFmtStp=StringFormat($sStrFmtStp,$iStepTot)
			While _TimerSleep(1)
				$vReadOut = StdoutRead($iWimLibPid, True)
				$iErrOut = @error
				$vReadErr = StderrRead($iWimLibPid, True)
				$iErrErr = @error
				If $vReadOut <> '' Then
					$sStdOut = StringStripWS(StringStripCR(StdoutRead($iWimLibPid)), 7)
				EndIf
				If $vReadErr <> '' Then
					$sStdErr = StringStripWS(StringStripCR(StderrRead($iWimLibPid)), 7)
				EndIf
				If Not ProcessExists($iWimLibPid) Or $iErrOut <> 0 Or $iErrErr <> 0 Then ExitLoop
				If StringRegExp($sStdOut, $areMatch[0]) Then
					$vMatch=StringRegExp($sStdOut, $areMatch[0],1)
					GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp&" (%s/%s,%s%)",1,"Creating files",$vMatch[0],$vMatch[1],$vMatch[2]))
					_SetProgress($gidProgStp, $vMatch[2])
					_SetProgress($gidProgStg, ($vMatch[2] / 300) * 100)
					_SetProgress($gidProgTot, ((9 + $vMatch[2]) / $iTotMax) * 100)
				ElseIf StringRegExp($sStdOut, $areMatch[1]) Then
					$vMatch = StringRegExp($sStdOut, $areMatch[1], 1)
					GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp&" (%s%s/%s%s,%s%)",2,"Extracting File Data",$vMatch[0],$vMatch[1],$vMatch[2],$vMatch[3],$vMatch[4]))
					_SetProgress($gidProgStp, $vMatch[4])
					_SetProgress($gidProgStg, ((100 + $vMatch[4]) / 300) * 100)
					_SetProgress($gidProgTot, ((9 + 100 + $vMatch[4]) / $iTotMax) * 100)
				ElseIf StringRegExp($sStdOut, $areMatch[2]) Then
					$vMatch = StringRegExp($sStdOut, $areMatch[2], 1)
					GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp&" (%s/%s,%s%)",3,"Applying File Metadata",$vMatch[0],$vMatch[1],$vMatch[2]))
					_SetProgress($gidProgStp, $vMatch[2])
					_SetProgress($gidProgStg, ((200 + $vMatch[2]) / 300) * 100)
					_SetProgress($gidProgTot, ((9 + 200 + $vMatch[2]) / $iTotMax) * 100)
				EndIf
				If $bAbort Then
					If _AbortInstall() Then Return
				EndIf
				If $bPause Then
					_ProcessSuspend($hWimLibProc)
					While $bPause
						If $bAbort Then
							If _AbortInstall() Then Return
						EndIf
						Sleep(10)
					WEnd
					_ProcessResume($hWimLibProc)
				EndIf
				;Process Output
				;Creating files: 47000 of 142705 (32%) done
				;Extracting File Data: 1 GiB of 9 GiB (18%) done
				;Applying metadata to files: 25520 of 142705 (18%) done
			WEnd
            $iCode=_WinAPI_GetExitCodeProcess($hWimLibProc)
            If $iCode<>0 Then
                MsgBox(16,$sGuiTitle,StringFormat("Error: Installation Aborted! wimlib-imagex.exe returned an error:\r\n\r\n[Exitcode]\r\n%d\r\n\r\n[Cmdline]\r\n%s\r\n\r\n[STDERR]\r\n%s",$iCode,$sCmdLine,$sStdErr)&@CRLF)
                $iSetupStage = -1
                _GuiState(6)
                _Exit($iCode)
            EndIf
            ;_Log($sStdOut&@CRLF)
            _IncStage()
		Case 2 ; Integrate Drivers
            $iStepTot=5
            $sStrFmtStp=StringFormat($sStrFmtStp,$iStepTot)

            If Not FileExists("X:\initDrivers.ini") Then Return _IncStage()
            GUICtrlSetData($gidLabelStg, StringFormat($sStrFmtStg,$iSetupStage+1,"Integrating Drivers"))
            _SetProgress($gidProgStp, 0)
            Local $aDrivers=IniReadSection("X:\initDrivers.ini","drvload")
            If @error Then Return _IncStage()
            If $aDrivers[0][0]=0 Then Return _IncStage()
            GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,1,"Add Driver(s) to Windows..."))
			_SetProgress($gidProgStp, (1 / $iStepTot) * 100)
			_TimerSleep(1)
            If Not $bSim Then _injDrivers($aDrivers,"U:\\") ; Have to excape backslash due to StringFormat.
            Local $sDirCommon="U:\Windows\System32\Recovery"
            Local $sMountDir=$sDirCommon&"\WinRE-Mount"
            Local $sMountWim=$sDirCommon&"\WinRE.wim"
            If Not FileExists($sMountWim) Then
                _Log(StringFormat("~!Error@_InitInstall,WimWinRENotExist:%s\r\n",$sMountDir))
                Return _IncStage()
            EndIf
            GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,2,"Mounting WinRE.wim..."))
            _SetProgress($gidProgStp, (2 / $iStepTot) * 100)
            _TimerSleep(1)
            If Not $bSim Then
                If FileExists($sMountDir) Then
                    _Log(StringFormat("~!Warn@_InitInstall,MountDirPreExists:%s\r\n",$sMountDir))
                    If StringInStr(FileGetAttrib($sMountDir),"d") Then
                        _CleanupMountDir($sMountDir)
                    Else
                        _Log(StringFormat("~!Error@_InitInstall,MountDirIsAFile:%s\r\n",$sMountDir))
                        Return _IncStage()
                    EndIf
                EndIf
                If FileExists($sMountDir) Then
                    _Log(StringFormat("~!Error@_InitInstall,MountDirStillExists:%s\r\n",$sMountDir))
                    Return _IncStage()
                EndIf
                DirCreate($sMountDir)
                If Not FileExists($sMountDir) Then
                    _Log(StringFormat("~!Error@_InitInstall,MountDirNotCreated:%s\r\n",$sMountDir))
                    Return _IncStage()
                EndIf
                CmdGetOut(StringFormat('dism /Mount-Wim /WimFile:"%s" /Index:1 /MountDir:"%s"',$sMountWim,$sMountDir))
                If @Error Then
                    _CleanupMountDir($sMountDir)
                    Return _IncStage()
                EndIf
            EndIf
            GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,3,"Adding Drivers to WinRE..."))
            _SetProgress($gidProgStp, (3 / $iStepTot) * 100)
            _TimerSleep(125)
            If Not $bSim Then _injDrivers($aDrivers,$sMountDir)
            GUICtrlSetData($gidLabelStp, StringFormat($sStrFmtStp,4,"Saving WinRE.wim..."))
            _SetProgress($gidProgStp, (4 / $iStepTot) * 100)
            If Not $bSim Then
                CmdGetOut(StringFormat('dism /UnMount-Wim /MountDir:"%s" /Commit',$sMountDir))
                If @Error Then
                    _CleanupMountDir($sMountDir)
                    Return _IncStage()
                EndIf
                _CleanupMountDir($sMountDir)
            EndIf
            ; Dism Add Drivers to Sys
			_SetProgress($gidProgStp, 100)
			_SetProgress($gidProgStg, (($iSetupStage+1)/$iStgTot)*100)
			_SetProgress($gidProgTot, ($iStepTot/$iTotMax) * 100)
			_TimerSleep(1)
            _IncStage()
        Case 3 ; Copying Windows' boot files
			GUICtrlSetData($gidLabelStg, StringFormat($sStrFmtStg,$iSetupStage+1,"Copying System Files"))
			_SetProgress($gidProgStp, 0)
			_SetProgress($gidProgStg, 0)
			Local $aFilesA = StringSplit("boot.stl|bootmgfw.efi|bootmgr.efi|kd_02_10df.dll|kd_02_10ec.dll|kd_02_1137.dll|kd_02_14e4.dll|kd_02_15b3.dll|kd_02_1969.dll|kd_02_19a2.dll|kd_02_1af4.dll|kd_02_8086.dll|kd_07_1415.dll|kd_0C_8086.dll|kdnet_uart16550.dll|kdstub.dll|memtest.efi|winsipolicy.p7b", '|')
			Local $aFilesB = StringSplit("chs_boot.ttf|cht_boot.ttf|jpn_boot.ttf|kor_boot.ttf|malgun_boot.ttf|malgunn_boot.ttf|meiryo_boot.ttf|meiryon_boot.ttf|msjh_boot.ttf|msjhn_boot.ttf|msyh_boot.ttf|msyhn_boot.ttf|segmono_boot.ttf|segoe_slboot.ttf|segoen_slboot.ttf|wgl4_boot.ttf", '|')
			Local $aFilesC = StringSplit("WinRE.wim|ReAgent.xml", '|')
			Local $aFileList[][3] = [[6, '', ''], _
                ["U:\Windows\Boot\EFI", "T:\EFI\Microsoft\Boot", $aFilesA], _
                ["U:\Windows\Boot\Fonts", "T:\EFI\Microsoft\Boot\Fonts", $aFilesB], _
                ["U:\Windows\Boot\Resources", "T:\EFI\Microsoft\Boot\Resources", "bootres.dll"], _
                ["U:\Windows\Boot\EFI", "T:\EFI\Boot", "bootmgfw.efi"], _
                ["U:\Windows\Boot\DVD\EFI", "V:\Recovery\WindowsRE", "boot.sdi"], _
                ["U:\Windows\System32\Recovery", "V:\Recovery\WindowsRE", $aFilesC] _
            ]
			_InitCopy($aFileList, 309)
            If Not $bSim Then FileMove("T:\EFI\Boot\bootmgfw.efi","T:\EFI\Boot\bootx64.efi",9)
            _TimerSleep(125)
            _IncStage()
		Case 4 ; Configure BCD
			GUICtrlSetData($gidLabelStg, StringFormat($sStrFmtStg,$iSetupStage+1,"Configuring System"))
			_SetProgress($gidProgStp, 0)
			_SetProgress($gidProgStg, 0)
			$sBcdCmd = "bcdedit /store T:\EFI\Microsoft\Boot\BCD /set "
			If Not $bSim Then FileCopy($sDataDir & "\InfinitySys\bin\bcd", "T:\EFI\Microsoft\Boot\BCD", 9)
			_SetProgress($gidProgStp, (1 / 11) * 100)
			Local $iRet = 0
			Local $aCmds[] = [11, _
                $sBcdCmd & "{9dea862c-5cdd-4e70-acc1-f32b344d4795} device partition=T:", _
                $sBcdCmd & "{442e5a65-1bfe-11ee-832a-a39bc54a5df7} device partition=U:", _
                $sBcdCmd & "{442e5a65-1bfe-11ee-832a-a39bc54a5df7} osdevice partition=U:", _
                $sBcdCmd & '{442e5a65-1bfe-11ee-832a-a39bc54a5df7} description "Windows 11"', _
                $sBcdCmd & "{442e5a66-1bfe-11ee-832a-a39bc54a5df7} device ramdisk=[V:]\Recovery\WindowsRE\WinRE.wim,{442e5a67-1bfe-11ee-832a-a39bc54a5df7}", _
                $sBcdCmd & "{442e5a66-1bfe-11ee-832a-a39bc54a5df7} osdevice ramdisk=[V:]\Recovery\WindowsRE\WinRE.wim,{442e5a67-1bfe-11ee-832a-a39bc54a5df7}", _
                $sBcdCmd & "{442e5a64-1bfe-11ee-832a-a39bc54a5df7} device partition=U:", _
                $sBcdCmd & "{442e5a64-1bfe-11ee-832a-a39bc54a5df7} filedevice partition=U:", _
                $sBcdCmd & "{b2721d73-1db4-4c62-bf78-c548a880142d} device partition=T:", _
                $sBcdCmd & "{442e5a67-1bfe-11ee-832a-a39bc54a5df7} ramdisksdidevice partition=V:", _
                'U:\Windows\System32\reagentc.exe /setreimage /path "V:\Recovery\WindowsRE" /target U:\Windows' _
            ]
			For $i = 1 To $aCmds[0]
				GUICtrlSetData($gidLabelStp, 'Step (' & $i & '/' & $aCmds[0] & ") Cmd: " & $aCmds[$i])
				If _InstallInterrupt() Then Return
				If Not $bSim Then
                    If RunWait($aCmds[$i], $aCmds, @SW_HIDE, 0x10000) <> 0 Then $iRet += 2 ^ $i
                EndIf
				_SetProgress($gidProgStp, ($i / ($aCmds[0])) * 100)
				_SetProgress($gidProgStg, ($i / ($aCmds[0])) * 100)
				_SetProgress($gidProgTot, ((348 + $i) / $iTotMax) * 100)
			Next
            _SetProgress($gidProgStp, 100)
			_SetProgress($gidProgStg, 100)
			_SetProgress($gidProgTot, 100)
			GUICtrlSetData($gidLabelStp, "All Steps Completed")
			GUICtrlSetData($gidLabelStg, "All Stages Completed")
            _IncStage()
		Case 5 ; Finals
			$iSetupStage = -1
			_GuiState(6)
;~ 			If $bOptUnattend Then
;~ 				Local $aFileList[][3] = [ _
;~ 						[4, '', ''], _
;~ 						[@ScriptDir & "\InfinitySys\bin", "U:\Windows\Panther", "unattend.xml"], _
;~ 						[@ScriptDir & "\InfinitySys\bin", "U:\temp", "unattend.respecialize.xml"], _
;~ 						[@ScriptDir & "\InfinitySys\bin\util", "U:\temp\util", "WinUpdate.AutoReboot.exe"], _
;~ 						[@ScriptDir & "\InfinitySys\bin\util", "U:\temp\util", "InfDeployCleanup.exe"] _
;~ 						]
;~                 _InitCopy($aFileList, 359)
;~ 				FileCreateShortcut("C:\temp\util\InfDeployCleanup.exe", "U:\Users\Public\Desktop\DeployCleanup.lnk")
;~ 				FileCreateShortcut("C:\temp\util\WinUpdate.AutoReboot.exe", "U:\Users\Public\Desktop\WinUpdate.lnk")
;~ 			EndIf
;~ 			_Log($bOptAutoReboot & @CRLF)
			If $bOptAutoReboot Then
				$iSetupStage = -2
				_InitTimeout("Rebooting", "_AutoReboot")
				Return
			EndIf
			$iSetupStage = -1
	EndSwitch
EndFunc   ;==>_InitInstall

Func _InitTimeout($sMsg, $sCallback = -1)
	_GuiState(7)
	$_WndTimeoutMsg = $sMsg
	$_WndTimeoutMsgLast = GUICtrlRead($gidLabelTot)
	$_WndTimeoutTimer = TimerInit()
	$_WndTimeoutTimerLast = 0
	$_WndTimeoutTimeout = 5000
	$_WndTimeoutCallback = $sCallback
	AdlibRegister('_WndTimeout', 10)
EndFunc   ;==>_InitTimeout

Func _AbortTimeout()
	AdlibUnRegister("_WndTimeout")
    _SetProgress($gidProgTot,100)
	GUICtrlSetData($gidLabelTot, $_WndTimeoutMsgLast)
EndFunc   ;==>_AbortTimeout

Func _WndTimeout()
	$iTimer = TimerDiff($_WndTimeoutTimer)
	If $iTimer >= $_WndTimeoutTimerLast Then
		$_WndTimeoutTimerLast = $iTimer
		GUICtrlSetData($gidLabelTot, $_WndTimeoutMsg & " in (" & Ceiling(($_WndTimeoutTimeout - $iTimer) / 1000) & ')')
	EndIf
	GUICtrlSetData($gidProgTot, (($_WndTimeoutTimeout - $iTimer) / 5000) * 100)
	If $iTimer >= $_WndTimeoutTimeout Then
		AdlibUnRegister("_WndTimeout")
		GUICtrlSetData($gidLabelTot, $_WndTimeoutMsgLast)
		GUICtrlSetData($gidProgTot, 0)
		If $_WndTimeoutCallback <> -1 Then
			Call($_WndTimeoutCallback)
		EndIf
	EndIf
EndFunc   ;==>_WndTimeout

Func _IsDir($sPath)
	If Not FileExists($sPath) Then Return SetError(1, 0, 0)
	If Not StringInStr(FileGetAttrib($sPath), 'd') Then Return SetError(1, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_IsDir

Func _InitCopy($aList, $iTotal, $iC = 0)
	Local $aFiles
	Local $iErr = 0
	Local $iExt = 0
	Local $iCount = 0
	Local $c = 0
	Local $aFiles
	Local $hFile
	Local $sSrc
	Local $sDst
	Local $iProg
	;Get FileCount
	For $i = 1 To $aList[0][0]
		If $bAbort Then Return
		If IsArray($aList[$i][2]) Then
			$aFiles = $aList[$i][2]
			$iCount += $aFiles[0]
		Else
			$iCount += 1
		EndIf
	Next
	;_Log($iCount & @CRLF)
	$iFileTot = $iCount
	;Local $hProgressProc = DllCallbackRegister('_ProgressProc', 'bool', $tagCALLBACKSTATUS)
	$hProgressProc = DllCallbackRegister('_ProgressProc', 'bool', 'uint64;uint64;uint64;uint64;dword;dword;handle;handle;ptr')
	$pProgressProc = DllCallbackGetPtr($hProgressProc)
	For $i = 1 To $aList[0][0]
		If $bAbort Then Return
		If Not _IsDir($aList[$i][0]) Then
			$iErr = BitOR($iErr, 2 ^ $i)
			$c += 1
			ContinueLoop
		EndIf
		If Not DirCreate($aList[$i][1]) Then
			$iErr = BitOR($iErr, 2 ^ $i + 1)
			$c += 1
			ContinueLoop
		EndIf
		_SetProgress($gidProgStp, 0)
		If IsArray($aList[$i][2]) Then
			$aFiles = $aList[$i][2]
			For $j = 1 To $aFiles[0]
				$gsProgLblStp = 'Step (' & $c + 1 & '/' & $iCount & ") Copying: " & $aFiles[$j]
				If $bAbort Then Return
				GUICtrlSetData($gidLabelStp, 'Step (' & $c + 1 & '/' & $iCount & ") Copying: " & $aFiles[$j] & "(0B/0B,0%)")
				$sSrc = $aList[$i][0] & '\' & $aFiles[$j]
				If Not FileExists($sSrc) Then
					$iExt = BitOR($iExt, 2 ^ ($i * $j))
					$c += 1
					ContinueLoop
				EndIf
				$sDst = $aList[$i][1] & '\' & $aFiles[$j]
				$iFileCur = $c
				_SetProgress($gidProgStp, 0)
				; This Method DOES hang after a few seconds when copying large files (like winre.wim), possible workaround is spawn child process and stdio for progress.
                _Log('"'&$sSrc&'"->"'&$sDst&'"')
                If Not $bSim Then _Log(_WinAPI_CopyFileEx($sSrc, $sDst, 0, $pProgressProc)&@CRLF)
				$c += 1
				_SetProgress($gidProgStp, 100)
				_SetProgress($gidProgStg, ($c / $iFileTot) * 100)
				_SetProgress($gidProgTot, (($iTotal + $c) / $iTotMax) * 100)
			Next
		Else
			$gsProgLblStp = 'Step (' & $c + 1 & '/' & $iCount & ") Copying: " & $aList[$i][2]
			GUICtrlSetData($gidLabelStp, 'Step (' & $c + 1 & '/' & $iCount & ") Copying: " & $aList[$i][2] & "(0B/0B,0%)")
			$sSrc = $aList[$i][0] & '\' & $aList[$i][2]
			If Not FileExists($sSrc) Then
				$iExt = BitOR($iExt, 2 ^ ($i * $j))
				$c += 1
				ContinueLoop
			EndIf
			$sDst = $aList[$i][1] & '\' & $aList[$i][2]
			$iFileCur = $c
			_SetProgress($gidProgStp, 0)
			;_SetProgress($gidProgTot,((309+18+16+$i)/$iFileTot)*100)
			; This Method DOES hang after a few seconds when copying large files (like winre.wim), possible workaround is spawn child process and stdio for progress.
            _Log('"'&$sSrc&'"->"'&$sDst&'"')
			If Not $bSim Then _Log(_WinAPI_CopyFileEx($sSrc, $sDst, 0, $pProgressProc)&@CRLF)
			$c += 1
			_SetProgress($gidProgStp, 100)
			_SetProgress($gidProgStg, ($c / $iFileTot) * 100)
			_SetProgress($gidProgTot, (($iTotal + $c) / $iTotMax) * 100)
		EndIf
	Next
	DllCallbackFree($hProgressProc)
EndFunc   ;==>_InitCopy

Func _ProgressProc($iTotalFileSize, $iTotalBytesTransferred, $iStreamSize, $iStreamBytesTransferred, $iStreamNumber, $iCallbackReason, $hSourceFile, $hDestinationFile, $pData)
	#forceref $iStreamSize, $iStreamBytesTransferred, $iStreamNumber, $iCallbackReason, $hSourceFile, $hDestinationFile, $pData
	Local $iProg = Round($iTotalBytesTransferred / $iTotalFileSize * 100)
	Local $iCopied = $iTotalBytesTransferred == 0 ? "0B" : ConvertSize($iTotalBytesTransferred)
	Local $iTotal = $iTotalFileSize == 0 ? "0B" : ConvertSize($iTotalFileSize)
	GUICtrlSetData($gidLabelStp, $gsProgLblStp & " (" & $iCopied & "/" & $iTotal & "," & $iProg & "%)")
	_SetProgress($gidProgStp, $iProg)
	If $bAbort Then Return $PROGRESS_CANCEL
	Return $PROGRESS_CONTINUE
EndFunc   ;==>_ProgressProc

Func _GuiState($iState)
    ;_Log("iState:"&$iState&@CRLF)
	Switch $iState
		Case -1 ; Revert
			_GuiCtrlState($iGuiLastState)
			_GuiCtrlState($iGuiOptLastState,1)
		Case 0 ; Initial
			_GuiCtrlState(2,1) ; Auto Reboot Enabled.
			_GuiCtrlState(8,2) ; Install Visible.
			_GuiCtrlState(4)    ; Only Rescan Enabled.
			_RefreshDisks()
		Case 1 ; Disk Selected
			_GuiCtrlState(8,2)   ; Install Visible.
			_GuiCtrlState(2+4+16) ;  SelDisk+Rescan+SelWim+BrowseWim Enabled.
            ; Initialize WimSel
            _SelSetStatic($ghWimIdx,"No WIM/ESD Image selected.",32,1)
			_ScanWims()
		Case 2 ; Disabled
            ; While ScanDisk+BrowseWim
			$iGuiLastState=$iGuiState
			$iGuiOptLastState=$iGuiOptState
			_GuiCtrlState(2048) ; Only Abort Visible.
		Case 3 ; Installing
			_GuiCtrlState(2,2) ; Pause Visible
            _GuiCtrlState(64+128+256+512+1024) ; Opt(s)+Pause+Resume+Install+Abort Enabled
		Case 4 ; Paused
			_GuiCtrlState(4,2) ; Resume Visible
            _GuiCtrlState(64+128+256+512+1024) ; Opt(s)+Pause+Resume+Install+Abort Enabled
		Case 5 ; Resume
			_GuiCtrlState(2,2) ; Pause Visible
            _GuiCtrlState(64+128+256+512+1024) ; Opt(s)+Pause+Resume+Install+Abort Enabled
		Case 6 ; Post Install
            WinActivate($hMain)
			_GuiCtrlState(8,2) ; Install Visible
			_GuiCtrlState(0) ; Only Quit Enabled
		Case 7 ; Timeout Mode
            WinActivate($hMain)
			_GuiCtrlState(8,2) ; Install Visible
            ;_GuiCtrlState(0, 1)
            ;_GuiCtrlState(0)
			_GuiCtrlState(1024) ; Only Abort Enabled
		Case 8 ; Abort Install
			_GuiCtrlState(8,2) ; Install Visible
			_GuiCtrlState(2+4+8+16+32+64+128+256+512); SelDisk+Rescan+SelWim+BrowseWim+SelWimIdx+Opt(s)+Pause+Resume+Install
	EndSwitch
EndFunc   ;==>_GuiState

Func _GuiEvtButton()
	Switch @GUI_CtrlId
		Case $agidBtn[1] ; Pause
			$bPause = 1
			_GuiState(4)
		Case $agidBtn[2] ; Resume
			$bPause = 0
			_GuiState(3)
		Case $agidBtn[3] ; Install
            Local $sVol=StringLeft($sWimPath,2)
            ;_Log("sVol:"&$sVol&@CRLF)
            If StringInStr("T:U:V:",$sVol) Then
                MsgBox(48,$sGuiTitle,StringFormat('WARNING: "%s" resides on a volume that needs to be unmounted for installation to continue. Please select or browse for an alternate image to continue.\n\nNOTE: The installation mounts the target volumes on T: U: and V:',$sWimPath))
                Return
            Else
                ;_Log($aDisks[$iDisk+1][3]&@CRLF)
                If StringInStr($aDisks[$iDisk+1][3],$sVol) Then
                    MsgBox(48,$sGuiTitle,StringFormat("WARNING: This install image resides on the disk that has been selected for installation. Installation cannot continue. Please select a different disk, or browse for an alternative image to continue."))
                    Return
                EndIf
            EndIf
            If Not FileExists($sWimPath) Then
                MsgBox(16,$sGuiTitle,StringFormat('Error: Install image "%s" cannot be found, Installation Aborted!',$sWimPath))
                _AbortInstall()
                ;$iSetupStage=-1
                ;_GuiState(8)
                Return
            EndIf
          	$iRet = MsgBox(48 + 1, $sGuiTitle,StringFormat("WARNING: The target disk will be reformatted, and any data overwritten may be unrecoverable.\n\nAre you certain you want to procced with the installation?"))
            If $iRet <> 1 Then Return 0
            If Not $bSim Then
                Local $sRet=_umountInstVols()
                If @Error Then
                    MsgBox(16,$sGuiTitle,StringFormat('Error: Cannot unmount %s\. Installation Aborted!\n\nPlease ensure no files are in use on %s\ and try again, or unmount manually.',$sRet,$sRet))
                    Return
                EndIf
            EndIf
			$iSetupStage = 0
            _SendMessage($ghProgStp, $PBM_SETSTATE, 1) ; green
            _SendMessage($ghProgStg, $PBM_SETSTATE, 1)
            _SendMessage($ghProgTot, $PBM_SETSTATE, 1)
			AdlibRegister("_InitInstall",1)
			_GuiState(3)
		Case $agidBtn[4] ; Abort
			If $iSetupStage == -1 Then ; Idle Menu
				;If $iDisk <> -1 Then
				;	_GuiState(1)
				;Else
				;	_GuiState(0)
				;EndIf
                _GuiState(0)
				_AbortTimeout()
			ElseIf $iSetupStage == -2 Then ; Post Install
				_GuiState(6)
				_AbortTimeout()
			Else ; Active Install
				$bAbort = 1
			EndIf
		Case $agidBtn[5] ; Tools (Base)
            ShowMenu($hMain, @GUI_CtrlId, $idUtilMenu)
        Case $agidBtn[6] ; Quit
            If $iSetupStage>=0 Then
                MsgBox(32,$sGuiTitle,"Please Abort the current installation before attempting to exit!")
                Return
            EndIf
			ShowMenu($hMain, @GUI_CtrlId, $idExitMenu)
		Case $gidDiskScan
			_GuiState(2)
			_RefreshDisks()
            _ScanWims()
			_GuiState(-1)
            _SetWimSelState()
        Case $gidExitMenuExit
            _Exit(0,0)
        Case $gidExitMenuShut
            _Exit(0,1)
        Case $gidExitMenuRebt
            _Exit(0,2)
        Case $gidWimSel
            Return MsgBox(48,$sGuiTitle,"Not yet implemented")
            _GuiState(2)
            FileOpenDialog($sGuiTitle,"","Windows Image (*.wim; *.esd; *.swm)",3)
            _GuiState(-1)
            return
    EndSwitch
    Local $sCmd=""
    For $i=1 To $aUtils[0][0]
        If @GUI_CtrlId<>$aUtils[$i][0] Then ContinueLoop
        If FileExists($aUtils[$i][6]) Then
            $sCmd=$aUtils[$i][6]
        Else
            $sCmd=$gsUtilDir&'\'&$aUtils[$i][1]&'\'&$aUtils[$i][6]
        EndIf
        If $aUtils[$i][7]<>'' Then $sCmd&=' '&$aUtils[$i][7]
        _Log(StringFormat('~!ExecUtil@GuiEvtBtn:"%s"\r\n',$sCmd))
        Run($sCmd,$gsUtilDir&'\'&$aUtils[$i][1],@SW_SHOW,0x10000)
    Next
EndFunc   ;==>_GuiEvtButton

Func _SelDisk($iIndex)
	$oDisk = 0
	For $oObj In $oDisks
		If $oObj.Number <> $aDisks[$iIndex+1][0] Then ContinueLoop
		$oDisk = $oObj
		$iDisk = $aDisks[$iIndex+1][0]
		ExitLoop
	Next
	;_ScanWims()
	;_Log($iDisk & @CRLF)
	_GuiState(1)
	_GUICtrlComboBox_SetCurSel($ghDisks, $iDisk)
EndFunc   ;==>_SelDisk

Func _SelWim($iIndex,$iUpdate=0)
	;_GuiState(1)
    _GuiCtrlState(BitAND($iGuiState,BitNOT(64+128+256+512)))
    ;_Log($aWims[$iIndex+1][0]&','&$iIndex&@CRLF)
    $sWimPath=$aWims[$iIndex+1][0]
	_GUICtrlComboBox_SetCurSel($ghWim, $iIndex)
    _SelSetStatic($ghWimIdx,"Checking...",32)
    $aWimImages=_WimGetInfo($sWimPath)
    If Not @error Then
        If Not $aWimImages[0][0] Then Return
        _GUICtrlComboBox_BeginUpdate($ghWimIdx)
        _GUICtrlComboBox_ResetContent($ghWimIdx)
        For $i = 1 To $aWimImages[0][0]
            ;_Log($aWimImages[$i][1]&@CRLF)
            _GUICtrlComboBox_AddString($ghWimIdx,StringFormat("Index %d: %s",$i,$aWimImages[$i][1]))
        Next
        ;If $aWims[0][0]=1 Then _GUICtrlComboBox_SetCurSel($ghWim, $aWims[0][0])
        _GUICtrlComboBox_EndUpdate($ghWimIdx)
    Else

    EndIf
    _SetWimIdxSelState()
EndFunc   ;==>_SelDisk

Func _SelWimIdx($iIndex)
    $iWimIdx=$iIndex
    ;_Log($iWimIdx&@CRLF)
    _GuiCtrlState(BitOR($iGuiState,64+128+256+512))
EndFunc   ;==>_SelDisk

Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
        #forceref $hWnd, $iMsg, $wParam
        If $hWnd <> $hMain Then Return $GUI_RUNDEFMSG
        Local $tHeader   = DllStructCreate($tagNMHDR, $lParam)
        Local $hWndFrom  = HWnd(DllStructGetData($tHeader, "hWndFrom"))
        ;If $hWndFrom <> $hMain Then Return $GUI_RUNDEFMSG
        Local $idCtrl    = DllStructGetData($tHeader, "IDFrom")
        Local $iCode = DllStructGetData($tHeader, "Code")
        If $iCode <> $BCN_DROPDOWN Then Return $GUI_RUNDEFMSG
        If $idCtrl==$agidBtn[5] Then ShowMenu($hMain, $idCtrl, $idUtilMenu)
        If $idCtrl==$agidBtn[6] Then ShowMenu($hMain, $idCtrl, $idExitMenu)
        Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY

Func WM_COMMAND($hWnd, $Msg, $wParam, $lParam)
	Local $idCtrl = BitAND($wParam, 0x0000FFFF)
	Local $iCode = BitShift($wParam, 16)
	If $hWnd <> $hMain Then Return $GUI_RUNDEFMSG
	If $iCode <> $CBN_SELCHANGE Then Return $GUI_RUNDEFMSG
	;If $idCtrl <> $gidDisk Then Return $GUI_RUNDEFMSG
    Switch $idCtrl
        Case $gidWim
            Local $iSel=_GUICtrlComboBox_GetCurSel($ghWim)
            _SelWim($iSel)
            ;_Log($iWim&@CRLF)
        Case $gidWimIdx
            ;Return $GUI_RUNDEFMSG
            _SelWimIdx(_GUICtrlComboBox_GetCurSel($ghWimIdx))
            ;_Log($iWim&@CRLF)
        Case $gidDisk
            ;_Log(_GUICtrlComboBox_GetCurSel($ghDisks)&@CRLF)
            _SelDisk(_GUICtrlComboBox_GetCurSel($ghDisks))
            ;_Log($iDisk&@CRLF)
        Case Default
            Return $GUI_RUNDEFMSG
    EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_COMMAND

Func _SetDiskSelState()
	_GUICtrlComboBox_BeginUpdate($ghDisks)
    If _DrvChk() Then
        _SelSetStatic($ghDisks,"Drive Conflict",2)
        _GUICtrlComboBox_EndUpdate($ghDisks)
        MsgBox(16,$sGuiTitle,"Error: One or more drives are mapped/mounted to T: U: or V:  please unmount/unmap or remove these drives and try again.")
        ;_GuiState()
        Return
    EndIf
	If $aDisks[0][0] > 0 Then
		_GuiCtrlState(BitOR($iGuiState, 2))
		_GUICtrlComboBox_SetCueBanner($ghDisks, "Select Disk")
        _SelSetStatic($ghWim,"No Disk Selected.",8,1)
        _SelSetStatic($ghWimIdx,"No Disk Selected.",32,1)
	Else
        _SelSetStatic($ghDisks,"No Disks Found",2)
	EndIf
	_GUICtrlComboBox_EndUpdate($ghDisks)
EndFunc   ;==>_SetDiskSelState

Func _SetWimSelState()
	_GUICtrlComboBox_BeginUpdate($ghWim)
	If $aWims[0][0] > 0 Then
		_GuiCtrlState(BitOR($iGuiState, 8))
		_GUICtrlComboBox_SetCueBanner($ghWim, "Select WIM/ESD")
        _SelSetStatic($ghWimIdx,"No WIM/ESD Image selected.",32,1)
        _GUICtrlComboBox_EndUpdate($ghWim)
        If $aWims[0][0]=1 Then
            _SelWim(0)
            _GuiCtrlState(BitXOR($iGuiState, 8))
        EndIf
    Else
       ; _GUICtrlComboBox_BeginUpdate($ghWim)
        ;_GUICtrlComboBox_ResetContent($ghWim)
        _SelSetStatic($ghWim,"No WIM/ESD Images Found",8,1)
        _SelSetStatic($ghWimIdx,"No WIM/ESD Image selected.",32,1)
        _GuiCtrlState(BitXOR($iGuiState, 8+32))
	EndIf
EndFunc

Func _SetWimIdxSelState()
	_GUICtrlComboBox_BeginUpdate($ghWimIdx)
    ;If Not IsArray($aWimImages) Then
    ;    _SelSetStatic($ghWimIdx,"WIM/ESD has no Images",32)
    ;    Return
    ;EndIf
	If $aWimImages[0][0] > 0 Then
		_GuiCtrlState(BitOR($iGuiState, 32))
		_GUICtrlComboBox_SetCueBanner($ghWimIdx, "Select Index")
        Else
        _SelSetStatic($ghWimIdx,"WIM/ESD has no Images",32)
	EndIf
    _GUICtrlComboBox_EndUpdate($ghWimIdx)
    If $aWimImages[0][0]=1 Then
        _GUICtrlComboBox_SetCurSel($ghWimIdx,0)
        _GuiCtrlState(BitAND($iGuiState,BitNOT(32)))
        _SelWimIdx(0)
    EndIf
EndFunc

Func _SelSetStatic($hCtrl,$sText,$iState,$iUpdate=0)
	If $iUpdate Then _GUICtrlComboBox_BeginUpdate($hCtrl)
	_GUICtrlComboBox_ResetContent($hCtrl)
    _GuiCtrlState(BitOR($iGuiState, $iState))
    _GUICtrlComboBox_AddString($hCtrl, $sText)
    _GUICtrlComboBox_SetCurSel($hCtrl, 0)
    ;_GuiCtrlState(BitXOR($iGuiState, $iState))
    _GuiCtrlState(BitAND($iGuiState,BitNOT($iState)))
	If $iUpdate Then _GUICtrlComboBox_EndUpdate($hCtrl)
EndFunc

Func _DebugState($iNewState)
    _Log("0b"&_ToBase($iGuiState,2,16)&@LF&"0b"&_ToBase($iNewState,2,16)&@CRLF)
    Return $iNewState
EndFunc

Func _RefreshDisks()
    _SelSetStatic($ghDisks,"Scanning...",2,1)
    _ScanDisks()
    _TimerSleep(125)
	_GUICtrlComboBox_BeginUpdate($ghDisks)
	_GUICtrlComboBox_ResetContent($ghDisks)
	Local $i = 0
	For $i = 1 To $aDisks[0][0]
		_GUICtrlComboBox_AddString($ghDisks, "Disk " & $aDisks[$i][0] & ": " & $aDisks[$i][1] & " (" & $aDisks[$i][2] & ")")
	Next
	If $iDisk <> -1 Then _SelDisk($iDisk);_GUICtrlComboBox_SetCurSel($ghDisks, $iDisk+1)
	_GUICtrlComboBox_EndUpdate($ghDisks)
	_SetDiskSelState()
EndFunc

Func _ScanDisks()
	$oDisks = $oWmiSmp.ExecQuery('SELECT * FROM MSFT_Disk', "WQL", $iWbemFlags)
	Dim $aDisks[1][4]
    $aDisks[0][0]=0
    Local $oParts,$oVolumes,$sLetter,$iMax=0
	For $oDisk In $oDisks
        $iMax=UBound($aDisks,1)
        ReDim $aDisks[$iMax+1][4]
		$aDisks[$iMax][0] = $oDisk.Number
        $aDisks[$iMax][1] = ($oDisk.Size == 0 ? "0 B " : ConvertSize($oDisk.Size))
		$aDisks[$iMax][2] = $oDisk.FriendlyName
        $oParts = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Partition WHERE DiskNumber = " & $oDisk.Number,$iWbemFlags)
        $sLetter=""
        For $oPart In $oParts
            $oVolumes = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Volume",$iWbemFlags)
            For $oVol In $oVolumes
                If $oVol.DriveLetter <> $oPart.DriveLetter Then ContinueLoop
                $sLetter&=Chr($oVol.DriveLetter)&': '
            Next
        Next
        $aDisks[$iMax][3]=StringStripWS($sLetter,3)
        $aDisks[0][0]=$iMax
	Next
	If Not $iMax Then Return SetError(1, 0, 0)
    ;_ArrayNaturalSort(ByRef $avArray, $iDescending = 0, $iStart = 0, $iEnd = 0, $iSubItem = 0)
    _ArrayNaturalSort($aDisks,0,1)
	Return SetError(0, 0, 1)
EndFunc   ;==>_ScanDisks

Func _WhichWim($sPath, $sName = "install")
	$sPath &= '\' & $sName
	If FileExists($sPath & ".wim") Then Return SetError(0, 0, $sPath & ".wim")
	If FileExists($sPath & ".esd") Then Return SetError(0, 1, $sPath & ".esd")
	Return SetError(1, 0, 0)
EndFunc   ;==>_WhichWim

Func _FindImage($sPath = "Sources", $sImage = "Install")
	; When selecting our disk we'll call this again. Just to be sure our source image isnt on a doomed disk.
    Dim $aWims[1][2]
	$sWimPath = ""
	$sWimPath = _WhichWim("X:\" & $sPath, $sImage)
	If Not @error Then
		Return SetError(0, 0, $sWimPath)
	Else
		; Skip drive letters belonging to the drive we're wiping.
		Local $aSkip[] = [1, "x:"]
		Local $iMax = 0
		For $oObj In $oDisks
			If $oObj.Number <> $iDisk Then ContinueLoop ; If disk selected then skip it.
			$oParts = $oWmiSmp.ExecQuery("SELECT * FROM MSFT_Partition WHERE DiskNumber = " & $oObj.Number)
			For $oPart In $oParts
				If $oPart.DriveLetter == 0 Then ContinueLoop
				$iMax = UBound($aSkip, 1)
				ReDim $aSkip[$iMax + 1]
				$aSkip[$iMax] = StringLower(Chr($oPart.DriveLetter)) & ':'
			Next
		Next
		$aSkip[0] = $iMax
		$aDrives = DriveGetDrive("ALL")
		For $i = 1 To $aDrives[0]
			For $j = 1 To $aSkip[0]
				If $aDrives[$i] <> $aSkip[$j] Then ContinueLoop
				ContinueLoop 2
			Next
            $aFiles=_FileListToArrayRec(StringUpper($aDrives[$i])&'\'&$sPath,"install*.wim;install*.esd",1,0,0,2)
            If Not @error Then
                For $k=1 To $aFiles[0]
                    Local $iMaxWim=UBound($aWims,1)
                    ReDim $aWims[$iMaxWim+1][2]
                    $aWims[$iMaxWim][0]=$aFiles[$k]
                    $aWims[0][0]=$iMaxWim
                Next
            EndIf
		Next
	EndIf
	Return SetError(1, 0, 0)
EndFunc   ;==>_FindImage

Func _ScanWims()
    If BitAND($iGuiState,16) Then _GuiCtrlState(BitXOR($iGuiState, 16))
    _SelSetStatic($ghWim,"Searching...",8,1)
    _FindImage()
	_GUICtrlComboBox_BeginUpdate($ghWim)
	_GUICtrlComboBox_ResetContent($ghWim)
	For $i = 1 To $aWims[0][0]
		_GUICtrlComboBox_AddString($ghWim,StringFormat("Image: %s",$aWims[$i][0]))
	Next
	;If $aWims[0][0]=1 Then _GUICtrlComboBox_SetCurSel($ghWim, $aWims[0][0])
	_GUICtrlComboBox_EndUpdate($ghWim)
	;_SetDiskSelState()
    _SetWimSelState()
    _GuiCtrlState(BitOR($iGuiState, 16))
	Return SetError(0, 0, 1)
EndFunc   ;==>

Func _WimGetImages($sPath)
EndFunc
;_GuiCtrlState(0)
;_GuiCtrlState(1, 1)
;_GuiCtrlState(0, 2)
;; Default States
;_GuiState(0)

Func _GuiCtrlState($iState, $iMode = 0)
    ;_Log("0b"&_ToBase($iGuiState,2,16)&@LF&"0b"&_ToBase($iState,2,16)&@CRLF)
	If $iMode = 1 Then
	    ; [1] 0x2, Auto Reboot
		For $i = 1 To $agidOpt[0]
			GUICtrlSetState($agidOpt[$i], BitAND($iState, 2 ^ $i) ? $GUI_CHECKED : $GUI_UNCHECKED)
		Next
		$bOptAutoReboot = BitAND($iState, 2 ^ 1)
		$iGuiOptState = $iState
	ElseIf $iMode = 2 Then
        ; [1] 0x2, Pause
        ; [2] 0x4, Resume
        ; [3] 0x8, Install
		For $i = 1 To 3
			GUICtrlSetState($agidBtn[$i], BitAND($iState, 2 ^ $i) ? $GUI_SHOW : $GUI_HIDE)
		Next
		$iGuiState = BitOR($iState, $iGuiState)
	Else
		GUICtrlSetState($gidDisk, BitAND($iState, 2) ? $GUI_ENABLE : $GUI_DISABLE)      ; 0x2, Select Disk
		GUICtrlSetState($gidDiskScan, BitAND($iState, 4) ? $GUI_ENABLE : $GUI_DISABLE)  ; 0x4, Rescan
		GUICtrlSetState($gidWim, BitAND($iState, 8) ? $GUI_ENABLE : $GUI_DISABLE)       ; 0x8, Select WIM
		GUICtrlSetState($gidWimSel, BitAND($iState, 16) ? $GUI_ENABLE : $GUI_DISABLE)   ; 0x16, Browse for WIM
		GUICtrlSetState($gidWimIdx, BitAND($iState, 32) ? $GUI_ENABLE : $GUI_DISABLE)   ; 0x32, Select WIM Index
        ; [1] 0x64, Auto Reboot
		For $i = 1 To $agidOpt[0]
			GUICtrlSetState($agidOpt[$i], BitAND($iState, 2 ^ (5 + $i)) ? $GUI_ENABLE : $GUI_DISABLE)
		Next
        ; [1] 0x128, Pause
        ; [2] 0x256, Resume
        ; [3] 0x512, Install
        ; [4] 0x1024, Abort
		For $i = 1 To $agidBtn[0]-1
			GUICtrlSetState($agidBtn[$i], BitAND($iState, 2 ^ (5 + $agidOpt[0] + $i)) ? $GUI_ENABLE : $GUI_DISABLE)
		Next
        ; [5] 0x2048, Tools
        GUICtrlSetState($agidBtn[$agidBtn[0]-1], $GUI_ENABLE)
        ; [5] 0x4096, Quit
        GUICtrlSetState($agidBtn[$agidBtn[0]], $GUI_ENABLE)
		$iGuiState = $iState
	EndIf
EndFunc   ;==>_GuiCtrlState

Func _GuiEvtClose()
    If $iSetupStage>=0 Then
        $bAbort = 1
        $bAbortExit = 1
        Return
    EndIf
	_Exit()
EndFunc   ;==>_GuiEvtClose

Func _GuiEvtOpt()
	Switch @GUI_CtrlId
		;Case $agidOpt[1] ; Pause
		;	$bOptUnattend = (GUICtrlRead($agidOpt[1]) <> 4 ? 1 : 0)
		Case $agidOpt[1] ; Pause
			$bOptAutoReboot = (GUICtrlRead($agidOpt[1]) <> 4 ? 1 : 0)
	EndSwitch
EndFunc   ;==>_GuiEvtOpt

Func ShowMenu($hWnd, $idCtrl, $idContext)
	Local $aPos, $x, $y
	Local $hMenu = GUICtrlGetHandle($idContext)

	$aPos = ControlGetPos($hWnd, "", $idCtrl)

	$x = $aPos[0]
	$y = $aPos[1] + $aPos[3]

	ClientToScreen($hWnd, $x, $y)
	TrackPopupMenu($hWnd, $hMenu, $x, $y)
EndFunc   ;==>ShowMenu

Func ClientToScreen($hWnd, ByRef $x, ByRef $y)
	Local $tPoint = DllStructCreate("int;int")

	DllStructSetData($tPoint, 1, $x)
	DllStructSetData($tPoint, 2, $y)

	DllCall("user32.dll", "int", "ClientToScreen", "hwnd", $hWnd, "ptr", DllStructGetPtr($tPoint))

	$x = DllStructGetData($tPoint, 1)
	$y = DllStructGetData($tPoint, 2)
	; release Struct not really needed as it is a local
	$tPoint = 0
EndFunc   ;==>ClientToScreen

Func TrackPopupMenu($hWnd, $hMenu, $x, $y)
	DllCall("user32.dll", "int", "TrackPopupMenuEx", "hwnd", $hMenu, "int", 0x0020, "int", $x, "int", $y - ($iBtnH + 2), "hwnd", $hWnd, "ptr", 0)
EndFunc   ;==>TrackPopupMenu

Func ConvertSize($iSize, $iPrecision = 2)
	Local Const $aUnits = StringSplit("|K|M|G|T|P|E|Z|Y", '|', 2)
	Local $iUnit = Int(Log($iSize) / Log(1024))
	Return String(Round($iSize / 1024 ^ $iUnit, $iPrecision)) & '' & $aUnits[$iUnit] & "B"
EndFunc   ;==>ConvertSize

Func _TimeReadable($iTime)
	$sRet = ""
	$iSec = Int($iTime / 1000) ; convert miliseconds to seconds
	$iHour = Int($iSec / 3600) ; 3600 seconds in an hour
	$iMin = Int(($iSec - ($iHour * 3600)) / 60) ; 60 secs per min
	$iSec = $iSec - (($iHour * 3600) + ($iMin * 60)) ; leftovers
	$iMSec = ($iTime / 1000) - $iSec
	If $iHour > 0 Then
		If $iHour < 10 Then $iHour = "0" & $iHour
		$sRet &= $iHour & ':'
	EndIf
	If $iMin > 0 Then
		If $iMin < 10 Then $iMin = "0" & $iMin
		$sRet &= $iMin & ':'
	EndIf
	If $iSec < 10 Then
		$iSec = StringFormat("%02.4f", $iSec + $iMSec)
	Else
		$iSec = StringFormat("%.4f", $iSec + $iMSec)
	EndIf
	$sRet &= $iSec
	Return $sRet
EndFunc   ;==>_TimeReadable

Func _WinAPI_SetProcessDPIAwareness($iPROCESS_DPI_AWARENESS)
    Return DllCall('Shcore.dll', 'int', 'SetProcessDPIAwareness', 'int', $iPROCESS_DPI_AWARENESS)
EndFunc   ;==>_WinAPI_SetProcessDPIAwareness

Func _WimGetInfo($sPath)
    Local $sStdout="",$bExit=0,$aNfo[][2]=[[0,'']]
    $iPid=Run('"'&$sDataDir&'\InfinitySys\bin\wimlib-imagex.exe" info "'&$sPath&'"',"",@SW_HIDE,0x8)
    While Sleep(1)
        $vPeek=StdoutRead($iPid,1)
        If @error Then $bExit=1
        If $vPeek Then $sStdout&=StdoutRead($iPid)
        If $bExit Then ExitLoop
    WEnd
    If $sStdout="" Then Return SetError(1,0,0)
    $aArr=StringRegExp($sStdout,"(?m)(?:^Index:\s+(\d+)$\r?\n^Name:\s+([^(?:\r?\n)]+))+",3)
    If @error Then Return SetError(1,1,0)
    Local $iMax
    For $i=0 To UBound($aArr,1)-1 Step 2
        $iMax=UBound($aNfo,1)
        ReDim $aNfo[$iMax+1][2]
        $aNfo[$iMax][0]=$aArr[$i]
        $aNfo[$iMax][1]=$aArr[$i+1]
    Next
    $aNfo[0][0]=$iMax
    ;_ArrayDisplay($aNfo)
    Return SetError(0,0,$aNfo)
EndFunc

Func _ToBase($iNumber, $iBase, $iPad = 1)
    Local $sRet = "", $iDigit
    Do
        $iDigit = Mod($iNumber, $iBase)
        If $iDigit < 10 Then
            $sRet = String($iDigit) & $sRet
        Else
            $sRet = Chr(55 + $iDigit) & $sRet
        EndIf
        $iNumber = Int($iNumber / $iBase)
    Until ($iNumber = 0) And (StringLen($sRet) >= $iPad)
    Return $sRet
EndFunc   ;==>_ToBase

Func _DrvChk()
    For $i=1 To UBound($aDisks,1)-1
        If StringInStr("T:U:V:",StringLower($aDisks[$i][3])) Then Return 1
    Next
    Return 0
EndFunc

Func _umountInstVols()
    Local $aDrives=DriveGetDrive("ALL")
    If @error Then Return SetError(1,0,1)
    For $i=1 To $aDrives[0]
        $sLtr=StringUpper($aDrives[$i])
        If Not StringInStr("T:U:V:",$sLtr) Then ContinueLoop
        $iResult=DllCall("Kernel32.dll","int","DeleteVolumeMountPoint","str",$sLtr&"\")
        If @error Then Return SetError(1,1,1)
        If $iResult[0]=0 Then Return SetError(1,2,$sLtr)
    Next
    Return SetError(0,0,0)
EndFunc

Func _IncStage()
    If _InstallInterrupt() Then Return
    $iSetupStage+=1
    AdlibRegister("_InitInstall",1)
EndFunc

Func _Log($sLine)
    ConsoleWrite($sLine)
    FileWriteLine("X:\Infinity.WinInst.log",$sLine)
EndFunc

Func _injDrivers(ByRef $aDrivers,$sTarget)
    ; Dism Add Drivers
    Local $sDrivers=StringFormat('dism /Image:"%s" /Add-Driver',$sTarget)
    For $t=1 To $aDrivers[0][0]
        $sDrivers&=StringFormat(' /Driver:"%s"',$aDrivers[$t][1])
    Next
    CmdGetOut($sDrivers)
EndFunc

Func CmdGetOutBin($sCmd,$sWorkDir=@SystemDir)
    Local $aml,$sBufOut,$sBufErr,$iPid,$vPeekOut,$vPeekErr,$sStdOut,$sStdErr,$hProc,$iCode,$sBufStr,$bBreak=0
    _Log(StringFormat("\r\n\r\nRun: [%s]",$sCmd)&@CRLF)
    $iPid=Run($sCmd,$sWorkDir,@SW_HIDE,0x6)
    $hProc=_WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION,0,$iPid)
    While True
        $vPeekOut=StdoutRead($iPid,1,1)
        If @error Then $bBreak=1
        $vPeekErr=StdErrRead($iPid,1,1)
        If @error Then $bBreak=1
        If $vPeekOut<>"" Then
            $sStdOut=StdoutRead($iPid,0,1)
            If @error Then $bBreak=1
            $sBufOut&=$sStdOut
            $sBufStr=BinaryToString($sStdOut)
            If StringInStr($sBufStr,@CRLF) Then
                $aml=StringSplit(StringStripCR($sBufStr),@LF,1)
                For $x=1 To $aml[0]
                    _Log(StringFormat("[%s][stdout]: %s\r\n",$iPid,($aml[$x])))
                Next
            Else
                _Log($sBufStr)
            EndIf
        EndIf
        If $vPeekErr<>"" Then
            $sStdErr=StderrRead($iPid,0,1)
            If @error Then $bBreak=1
            $sBufErr&=$sStdErr
            $sBufStr=BinaryToString($sStdErr)
            If StringInStr($sBufStr,@CRLF) Then
                $aml=StringSplit(StringStripCR($sBufStr),@LF,1)
                For $x=1 To $aml[0]
                    _Log(StringFormat("[%s][stderr]: %s\r\n",$iPid,($aml[$x])))
                Next
            Else
                _Log($sBufStr)
            EndIf
        EndIf
        If $bBreak Then ExitLoop
    WEnd
    $iCode=_WinAPI_GetExitCodeProcess($hProc)
    _WinAPI_CloseHandle($hProc)
    _Log(StringFormat("[%s] Exit Code: 0x%X\r\n",$iPid,$iCode))
    Local $aRet[]=[$iCode,$sBufOut,$sBufOut]
    Return SetError($iCode,0)
EndFunc

Func CmdGetOut($sCmd,$sWorkDir=@SystemDir)
    Local $sBuf,$iPid,$vPeek,$sStdOut,$hProc,$iCode,$bBreak=0
    _Log(StringFormat("\r\n\r\nRun: [%s]",$sCmd)&@CRLF)
    $iPid=Run($sCmd,$sWorkDir,@SW_HIDE,0x8)
    While Sleep(1)
        $vPeek=StdoutRead($iPid,1,0)
        If @error Then $bBreak=1
        If $vPeek<>"" Then
            $sStdOut=StdoutRead($iPid)
            If @error Then $bBreak=1
            $sBuf&=$sStdOut
            If StringInStr($sStdOut,@CRLF) Then
                $aml=StringSplit(StringStripCR($sStdOut),@LF,1)
                For $x=1 To $aml[0]
                    _Log(StringFormat("[%s]: %s\r\n",$iPid,($aml[$x])))
                Next
            Else
                _Log(StringFormat("[%s]: %s\r\n",$iPid,$sStdOut))
            EndIf
        EndIf
        If $bBreak Then ExitLoop
    WEnd
    $iCode=_WinAPI_GetExitCodeProcess($hProc)
    _WinAPI_CloseHandle($hProc)
    _Log(StringFormat("[%s] Exit Code: 0x%X\r\n",$iPid,$iCode))
    Return SetError($iCode,0,$sBuf)
EndFunc

Func _CleanupMountDir($sMountDir)
    CmdGetOut(StringFormat('dism /UnMount-Wim /MountDir:"%s" /Discard',$sMountDir))
    CmdGetOut("dism /Cleanup-Wim")
    DirRemove($sMountDir,1)
EndFunc
