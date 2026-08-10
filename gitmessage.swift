codex conversation [20260810-ipad] animate popup height after its collapsed frame renders

Insert the collapsed popup without an enclosing animation, then begin its size
and offset springs after one rendered frame. This preserves the height-growth
animation when the list has intrinsic content size without a ScrollView.
