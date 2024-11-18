#include-once
#include <NaturalCompare.au3>
#include <ArrayCustomSort.au3>

; #FUNCTION# ====================================================================================================================
; Name...........: _ArrayNaturalSort
; Description ...: Sort a 1D or 2D array on a specific index using the quicksort/insertionsort algorithms.
; Syntax.........: _ArrayNaturalSort(ByRef $avArray[, $iDescending = 0[, $iStart = 0[, $iEnd = 0[, $iSubItem = 0]]]])
; Parameters ....: $avArray     - Array to sort
;                  $iDescending - [optional] If set to 1, sort descendingly
;                  $iStart      - [optional] Index of array to start sorting at
;                  $iEnd        - [optional] Index of array to stop sorting at
;                  $iSubItem    - [optional] Sub-index to sort on in 2D arrays
; Return values .: Success - 1
;                  Failure - 0, sets @error:
;                  |1 - $avArray is not an array
;                  |2 - $iStart is greater than $iEnd
;                  |3 - $iSubItem is greater than subitem count
;                  |4 - $avArray has too many dimensions
;                  |5 - Invalid sort function
; Author ........: Erik Pilsits
; Modified.......:
; Remarks .......:
; Related .......:
; Link ..........;
; Example .......; No
; ===============================================================================================================================
Func _ArrayNaturalSort(ByRef $avArray, $iDescending = 0, $iStart = 0, $iEnd = 0, $iSubItem = 0)
    Return _ArrayCustomSort($avArray, "_NaturalCompare", $iDescending, $iStart, $iEnd, $iSubItem)
EndFunc   ;==>_ArrayNaturalSort
