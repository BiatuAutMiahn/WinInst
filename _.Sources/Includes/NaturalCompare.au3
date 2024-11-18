#include-once
; #FUNCTION# ====================================================================================================================
; Name...........: _NaturalCompare
; Description ...: Compare two strings using Natural (Alphabetical) sorting.
; Syntax.........: _NaturalCompare($s1, $s2[, $iCase = 0])
; Parameters ....: $s1, $s2 - Strings to compare
;                  $iCase   - [Optional] Case sensitive or insensitive comparison
;                  |0 - Case insensitive (default)
;                  |1 - Case sensitive
; Return values .: Success - One of the following:
;                  |0  - Strings are equal
;                  |-1 - $s1 comes before $s2
;                  |1  - $s1 goes after $s2
;                  Failure - Returns -2 and Sets @Error:
;                  |1 - $s1 or $s2 is not a string
;                  |2 - $iCase is invalid
; Author ........: Erik Pilsits
; Modified.......:
; Remarks .......: Original algorithm by Dave Koelle
; Related .......: StringCompare
; Link ..........: http://www.davekoelle.com/alphanum.html
; Example .......: Yes
; ===============================================================================================================================
Func _NaturalCompare($s1, $s2, $iCase = 0)
    ; check params
    If (Not IsString($s1)) Then $s1 = String($s1)
    If (Not IsString($s2)) Then $s2 = String($s2)
    ; check case, set default
    If $iCase <> 0 And $iCase <> 1 Then $iCase = 0

    Local $n = 0
    Local $s1chunk, $s2chunk
    Local $idx, $i1chunk, $i2chunk
    Local $s1temp, $s2temp

    While $n = 0
        ; get next chunk
        ; STRING 1
        $s1chunk = StringRegExp($s1, "^(\d+|\D+)", 1)
        If @error Then
            $s1chunk = ""
        Else
            $s1chunk = $s1chunk[0]
        EndIf
        ; STRING 2
        $s2chunk = StringRegExp($s2, "^(\d+|\D+)", 1)
        If @error Then
            $s2chunk = ""
        Else
            $s2chunk = $s2chunk[0]
        EndIf

        ; ran out of chunks, strings are the same, return 0
        If $s1chunk = "" And $s2chunk = "" Then Return 0

        ; remove chunks from strings
        $s1 = StringMid($s1, StringLen($s1chunk) + 1)
        $s2 = StringMid($s2, StringLen($s2chunk) + 1)

        Select
            ; Case 1: both chunks contain letters
            Case (Not StringIsDigit($s1chunk)) And (Not StringIsDigit($s2chunk))
                $n = StringCompare($s1chunk, $s2chunk, $iCase)
            ; Case 2: both chunks contain numbers
            Case StringIsDigit($s1chunk) And StringIsDigit($s2chunk)
                ; strip leading 0's
                $s1temp = $s1chunk
                $s2temp = $s2chunk
                $s1chunk = StringRegExpReplace($s1chunk, "^0*", "")
                $s2chunk = StringRegExpReplace($s2chunk, "^0*", "")
                ; record number of stripped 0's
                $s1temp = StringLen($s1temp) - StringLen($s1chunk)
                $s2temp = StringLen($s2temp) - StringLen($s2chunk)
                ; first check if one string is longer than the other, meaning a bigger number
                If StringLen($s1chunk) > StringLen($s2chunk) Then
                    Return 1
                ElseIf StringLen($s1chunk) < StringLen($s2chunk) Then
                    Return -1
                EndIf
                ; strings are equal length
                ; compare 8 digits at a time, starting from the left, to avoid overflow
                $idx = 1
                While 1
                    $i1chunk = Int(StringMid($s1chunk, $idx, 8))
                    $i2chunk = Int(StringMid($s2chunk, $idx, 8))
                    ; check for end of string
                    If $i1chunk = "" And $i2chunk = "" Then
                        ; check number of leading 0's removed, if any - windows sorts more leading 0's above fewer leading 0's, ie 00001 < 0001 < 001
                        If $s1temp > $s2temp Then
                            Return -1
                        ElseIf $s1temp < $s2temp Then
                            Return 1
                        Else
                            ; numbers are equal
                            ExitLoop
                        EndIf
                    EndIf
                    ; valid numbers, so compare
                    If $i1chunk > $i2chunk Then
                        Return 1
                    ElseIf $i1chunk < $i2chunk Then
                        Return -1
                    EndIf
                    ; chunks are equal, get next chunk of digits
                    $idx += 8
                WEnd
            ; Case 3: one chunk has letters, the other has numbers; or one is empty
            Case Else
                ; if we get here, this should be the last and deciding test, so return the result
                Return StringCompare($s1chunk, $s2chunk, $iCase)
        EndSelect
    WEnd

    Return $n
EndFunc
