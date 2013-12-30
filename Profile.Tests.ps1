$sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests", "")
. (Resolve-Path $sut)



