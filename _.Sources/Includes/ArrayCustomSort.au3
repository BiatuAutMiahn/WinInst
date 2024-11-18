#include-once
#include <Array.au3>

; #FUNCTION# ====================================================================================================================
; Name ..........: _ArrayCustomSort
; Description ...: Sort a 1D or 2D array on a specific index using the quicksort/insertionsort algorithms, based on a custom sorting function.
; Syntax ........: _ArrayCustomSort(Byref $avArray, $sSortFunc[, $iDescending = 0[, $iStart = 0[, $iEnd = 0[, $iSubItem = 0]]]])
; Parameters ....: $avArray             - [in/out] Array to sort
;                  $sSortFunc           - Name of custom sorting function. See Remarks for usage.
;                  $iDescending         - [optional] If set to 1, sort descendingly
;                  $iStart              - [optional] Index of array to start sorting at
;                  $iEnd                - [optional] Index of array to stop sorting at
;                  $iSubItem            - [optional] Sub-index to sort on in 2D arrays
; Return values .: Success - 1
;                  Failure - 0, sets @error:
;                  |1 - $avArray is not an array
;                  |2 - $iStart is greater than $iEnd
;                  |3 - $iSubItem is greater than subitem count
;                  |4 - $avArray has too many dimensions
;                  |5 - Invalid sort function
; Author ........: Erik Pilsits
; Modified ......: Erik Pilsits - removed IsNumber testing, LazyCoder - added $iSubItem option, Tylo - implemented stable QuickSort algo, Jos van der Zande - changed logic to correctly Sort arrays with mixed Values and Strings, Ultima - major optimization, code cleanup, removed $i_Dim parameter
; Remarks .......: Sorting function is called with two array elements as arguments. The function should return
;                  0 if they are equal,
;                  -1 if element one comes before element two,
;                  1 if element one comes after element two.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _ArrayCustomSort(ByRef $avArray, $sSortFunc, $iDescending = 0, $iStart = 0, $iEnd = 0, $iSubItem = 0)
    If Not IsArray($avArray) Then Return SetError(1, 0, 0)
    If Not IsString($sSortFunc) Then Return SetError(5, 0, 0)

    Local $iUBound = UBound($avArray) - 1

    ; Bounds checking
    If $iEnd < 1 Or $iEnd > $iUBound Then $iEnd = $iUBound
    If $iStart < 0 Then $iStart = 0
    If $iStart > $iEnd Then Return SetError(2, 0, 0)

    ; Sort
    Switch UBound($avArray, 0)
        Case 1
            __ArrayCustomQuickSort1D($avArray, $sSortFunc, $iStart, $iEnd)
            If $iDescending Then _ArrayReverse($avArray, $iStart, $iEnd)
        Case 2
            Local $iSubMax = UBound($avArray, 2) - 1
            If $iSubItem > $iSubMax Then Return SetError(3, 0, 0)

            If $iDescending Then
                $iDescending = -1
            Else
                $iDescending = 1
            EndIf

            __ArrayCustomQuickSort2D($avArray, $sSortFunc, $iDescending, $iStart, $iEnd, $iSubItem, $iSubMax)
        Case Else
            Return SetError(4, 0, 0)
    EndSwitch

    Return 1
EndFunc   ;==>_ArrayCustomSort

; #INTERNAL_USE_ONLY#============================================================================================================
; Name...........: __ArrayCustomQuickSort1D
; Description ...: Helper function for sorting 1D arrays
; Syntax.........: __ArrayCustomQuickSort1D(ByRef $avArray, ByRef $sSortFunc, ByRef $iStart, ByRef $iEnd)
; Parameters ....: $avArray   - Array to sort
;                  $sSortFunc - Name of sorting function.
;                  $iStart    - Index of array to start sorting at
;                  $iEnd      - Index of array to stop sorting at
; Return values .: None
; Author ........: Jos van der Zande, LazyCoder, Tylo, Ultima
; Modified.......: Erik Pilsits - removed IsNumber testing
; Remarks .......: For Internal Use Only
; Related .......:
; Link ..........;
; Example .......;
; ===============================================================================================================================
Func __ArrayCustomQuickSort1D(ByRef $avArray, ByRef $sSortFunc, ByRef $iStart, ByRef $iEnd)
    If $iEnd <= $iStart Then Return

    Local $vTmp

    ; InsertionSort (faster for smaller segments)
    If ($iEnd - $iStart) < 15 Then
        Local $i, $j
        For $i = $iStart + 1 To $iEnd
            $vTmp = $avArray[$i]
            For $j = $i - 1 To $iStart Step -1
                If (Call($sSortFunc, $vTmp, $avArray[$j]) >= 0) Then ExitLoop
                $avArray[$j + 1] = $avArray[$j]
            Next
            $avArray[$j + 1] = $vTmp
        Next
        Return
    EndIf

    ; QuickSort
    Local $L = $iStart, $R = $iEnd, $vPivot = $avArray[Int(($iStart + $iEnd) / 2)]
    Do
        While (Call($sSortFunc, $avArray[$L], $vPivot) < 0)
            $L += 1
        WEnd
        While (Call($sSortFunc, $avArray[$R], $vPivot) > 0)
            $R -= 1
        WEnd

        ; Swap
        If $L <= $R Then
            $vTmp = $avArray[$L]
            $avArray[$L] = $avArray[$R]
            $avArray[$R] = $vTmp
            $L += 1
            $R -= 1
        EndIf
    Until $L > $R

    __ArrayCustomQuickSort1D($avArray, $sSortFunc, $iStart, $R)
    __ArrayCustomQuickSort1D($avArray, $sSortFunc, $L, $iEnd)
EndFunc   ;==>__ArrayCustomQuickSort1D

; #INTERNAL_USE_ONLY#============================================================================================================
; Name...........: __ArrayCustomQuickSort2D
; Description ...: Helper function for sorting 2D arrays
; Syntax.........: __ArrayCustomQuickSort2D(ByRef $avArray, ByRef $sSortFunc, ByRef $iStep, ByRef $iStart, ByRef $iEnd, ByRef $iSubItem, ByRef $iSubMax)
; Parameters ....: $avArray  - Array to sort
;                  $iStep    - Step size (should be 1 to sort ascending, -1 to sort descending!)
;                  $iStart   - Index of array to start sorting at
;                  $iEnd     - Index of array to stop sorting at
;                  $iSubItem - Sub-index to sort on in 2D arrays
;                  $iSubMax  - Maximum sub-index that array has
; Return values .: None
; Author ........: Jos van der Zande, LazyCoder, Tylo, Ultima
; Modified.......: Erik Pilsits - removed IsNumber testing
; Remarks .......: For Internal Use Only
; Related .......:
; Link ..........;
; Example .......;
; ===============================================================================================================================
Func __ArrayCustomQuickSort2D(ByRef $avArray, ByRef $sSortFunc, ByRef $iStep, ByRef $iStart, ByRef $iEnd, ByRef $iSubItem, ByRef $iSubMax)
    If $iEnd <= $iStart Then Return

    ; QuickSort
    Local $i, $vTmp, $L = $iStart, $R = $iEnd, $vPivot = $avArray[Int(($iStart + $iEnd) / 2)][$iSubItem]
    Do
        While ($iStep * Call($sSortFunc, $avArray[$L][$iSubItem], $vPivot) < 0)
            $L += 1
        WEnd
        While ($iStep * Call($sSortFunc, $avArray[$R][$iSubItem], $vPivot) > 0)
            $R -= 1
        WEnd

        ; Swap
        If $L <= $R Then
            For $i = 0 To $iSubMax
                $vTmp = $avArray[$L][$i]
                $avArray[$L][$i] = $avArray[$R][$i]
                $avArray[$R][$i] = $vTmp
            Next
            $L += 1
            $R -= 1
        EndIf
    Until $L > $R

    __ArrayCustomQuickSort2D($avArray, $sSortFunc, $iStep, $iStart, $R, $iSubItem, $iSubMax)
    __ArrayCustomQuickSort2D($avArray, $sSortFunc, $iStep, $L, $iEnd, $iSubItem, $iSubMax)
EndFunc   ;==>__ArrayCustomQuickSort2D
