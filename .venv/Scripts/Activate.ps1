<#
.Synopsis
Activate a Python virtual environment for the current PowerShell session.

.Description
Pushes the python executable for a virtual environment to the front of the
$Env:PATH environment variable and sets the prompt to signify that you are
in a Python virtual environment. Makes use of the command line switches as
well as the `pyvenv.cfg` file values present in the virtual environment.

.Parameter VenvDir
Path to the directory that contains the virtual environment to activate. The
default value for this is the parent of the directory that the Activate.ps1
script is located within.

.Parameter Prompt
The prompt prefix to display when this virtual environment is activated. By
default, this prompt is the name of the virtual environment folder (VenvDir)
surrounded by parentheses and followed by a single space (ie. '(.venv) ').

.Example
Activate.ps1
Activates the Python virtual environment that contains the Activate.ps1 script.

.Example
Activate.ps1 -Verbose
Activates the Python virtual environment that contains the Activate.ps1 script,
and shows extra information about the activation as it executes.

.Example
Activate.ps1 -VenvDir C:\Users\MyUser\Common\.venv
Activates the Python virtual environment located in the specified location.

.Example
Activate.ps1 -Prompt "MyPython"
Activates the Python virtual environment that contains the Activate.ps1 script,
and prefixes the current prompt with the specified string (surrounded in
parentheses) while the virtual environment is active.

.Notes
On Windows, it may be required to enable this Activate.ps1 script by setting the
execution policy for the user. You can do this by issuing the following PowerShell
command:

PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

For more information on Execution Policies: 
https://go.microsoft.com/fwlink/?LinkID=135170

#>
Param(
    [Parameter(Mandatory = $false)]
    [String]
    $VenvDir,
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt
)

<# Function declarations --------------------------------------------------- #>

<#
.Synopsis
Remove all shell session elements added by the Activate script, including the
addition of the virtual environment's Python executable from the beginning of
the PATH variable.

.Parameter NonDestructive
If present, do not remove this function from the global namespace for the
session.

#>
function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_VIRTUAL_PROMPT) {
        Copy-Item -Path Function:_OLD_VIRTUAL_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_VIRTUAL_PROMPT
    }

    # The prior PYTHONHOME:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PYTHONHOME) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME -Destination Env:PYTHONHOME
        Remove-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PATH) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_VIRTUAL_PATH
    }

    # Just remove the VIRTUAL_ENV altogether:
    if (Test-Path -Path Env:VIRTUAL_ENV) {
        Remove-Item -Path env:VIRTUAL_ENV
    }

    # Just remove VIRTUAL_ENV_PROMPT altogether.
    if (Test-Path -Path Env:VIRTUAL_ENV_PROMPT) {
        Remove-Item -Path env:VIRTUAL_ENV_PROMPT
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Scope Global -Force
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

<#
.Description
Get-PyVenvConfig parses the values from the pyvenv.cfg file located in the
given folder, and returns them in a map.

For each line in the pyvenv.cfg file, if that line can be parsed into exactly
two strings separated by `=` (with any amount of whitespace surrounding the =)
then it is considered a `key = value` line. The left hand string is the key,
the right hand is the value.

If the value starts with a `'` or a `"` then the first and last character is
stripped from the value before being captured.

.Parameter ConfigDir
Path to the directory that contains the `pyvenv.cfg` file.
#>
function Get-PyVenvConfig(
    [String]
    $ConfigDir
) {
    Write-Verbose "Given ConfigDir=$ConfigDir, obtain values in pyvenv.cfg"

    # Ensure the file exists, and issue a warning if it doesn't (but still allow the function to continue).
    $pyvenvConfigPath = Join-Path -Resolve -Path $ConfigDir -ChildPath 'pyvenv.cfg' -ErrorAction Continue

    # An empty map will be returned if no config file is found.
    $pyvenvConfig = @{ }

    if ($pyvenvConfigPath) {

        Write-Verbose "File exists, parse `key = value` lines"
        $pyvenvConfigContent = Get-Content -Path $pyvenvConfigPath

        $pyvenvConfigContent | ForEach-Object {
            $keyval = $PSItem -split "\s*=\s*", 2
            if ($keyval[0] -and $keyval[1]) {
                $val = $keyval[1]

                # Remove extraneous quotations around a string value.
                if ("'""".Contains($val.Substring(0, 1))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }

                $pyvenvConfig[$keyval[0]] = $val
                Write-Verbose "Adding Key: '$($keyval[0])'='$val'"
            }
        }
    }
    return $pyvenvConfig
}


<# Begin Activate script --------------------------------------------------- #>

# Determine the containing directory of this script
$VenvExecPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvExecDir = Get-Item -Path $VenvExecPath

Write-Verbose "Activation script is located in path: '$VenvExecPath'"
Write-Verbose "VenvExecDir Fullname: '$($VenvExecDir.FullName)"
Write-Verbose "VenvExecDir Name: '$($VenvExecDir.Name)"

# Set values required in priority: CmdLine, ConfigFile, Default
# First, get the location of the virtual environment, it might not be
# VenvExecDir if specified on the command line.
if ($VenvDir) {
    Write-Verbose "VenvDir given as parameter, using '$VenvDir' to determine values"
}
else {
    Write-Verbose "VenvDir not given as a parameter, using parent directory name as VenvDir."
    $VenvDir = $VenvExecDir.Parent.FullName.TrimEnd("\\/")
    Write-Verbose "VenvDir=$VenvDir"
}

# Next, read the `pyvenv.cfg` file to determine any required value such
# as `prompt`.
$pyvenvCfg = Get-PyVenvConfig -ConfigDir $VenvDir

# Next, set the prompt from the command line, or the config file, or
# just use the name of the virtual environment folder.
if ($Prompt) {
    Write-Verbose "Prompt specified as argument, using '$Prompt'"
}
else {
    Write-Verbose "Prompt not specified as argument to script, checking pyvenv.cfg value"
    if ($pyvenvCfg -and $pyvenvCfg['prompt']) {
        Write-Verbose "  Setting based on value in pyvenv.cfg='$($pyvenvCfg['prompt'])'"
        $Prompt = $pyvenvCfg['prompt'];
    }
    else {
        Write-Verbose "  Setting prompt based on parent's directory's name. (Is the directory name passed to venv module when creating the virtual environment)"
        Write-Verbose "  Got leaf-name of $VenvDir='$(Split-Path -Path $venvDir -Leaf)'"
        $Prompt = Split-Path -Path $venvDir -Leaf
    }
}

Write-Verbose "Prompt = '$Prompt'"
Write-Verbose "VenvDir='$VenvDir'"

# Deactivate any currently active virtual environment, but leave the
# deactivate function in place.
deactivate -nondestructive

# Now set the environment variable VIRTUAL_ENV, used by many tools to determine
# that there is an activated venv.
$env:VIRTUAL_ENV = $VenvDir

$env:VIRTUAL_ENV_PROMPT = $Prompt

if (-not $Env:VIRTUAL_ENV_DISABLE_PROMPT) {

    Write-Verbose "Setting prompt to '$Prompt'"

    # Set the prompt to include the env name
    # Make sure _OLD_VIRTUAL_PROMPT is global
    function global:_OLD_VIRTUAL_PROMPT { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_VIRTUAL_PROMPT
    New-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Description "Python virtual environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_PYTHON_VENV_PROMPT_PREFIX) "
        _OLD_VIRTUAL_PROMPT
    }
}

# Clear PYTHONHOME
if (Test-Path -Path Env:PYTHONHOME) {
    Copy-Item -Path Env:PYTHONHOME -Destination Env:_OLD_VIRTUAL_PYTHONHOME
    Remove-Item -Path Env:PYTHONHOME
}

# Add the venv to the PATH
Copy-Item -Path Env:PATH -Destination Env:_OLD_VIRTUAL_PATH
$Env:PATH = "$VenvExecDir$([System.IO.Path]::PathSeparator)$Env:PATH"

# SIG # Begin signature block
# MII28wYJKoZIhvcNAQcCoII25DCCNuACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBALKwKRFIhr2RY
# IW/WJLd9pc8a9sj/IoThKU92fTfKsKCCG1wwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwgga6MIIEoqADAgECAhMzAADG+FMd
# l5YYoDEAAAAAAMb4MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDMwHhcNMjYwNTA3MDcyNzE4WhcNMjYwNTEw
# MDcyNzE4WjB8MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGT3JlZ29uMRIwEAYDVQQH
# EwlCZWF2ZXJ0b24xIzAhBgNVBAoTGlB5dGhvbiBTb2Z0d2FyZSBGb3VuZGF0aW9u
# MSMwIQYDVQQDExpQeXRob24gU29mdHdhcmUgRm91bmRhdGlvbjCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAIj8oB35b6pLtltGegDbP60KxbIgtD1zVV5a
# DiQBJkssyiu1VfNotTETiBa+4xxQwEugoRFbLy0G98b9T5vhav98kTObdLxbjHv9
# TX5ZEtZY9ooY979k8p0RlIQWh054Rl8v1yIMtIoxJeJ+ZbNqDs85rld2R5tQ36lu
# WQVXWB/sht0aS2ykbS0Jpy0r5oT5UV/6Ho6fHsnHhfhBpPn75nZbFKRrM83HJtBV
# BQxczxxdH8mnWOUIK1/Yh2UsP7VmCuRuPpVwcr/dUxQ7B4/7/tmrzX79wGby34Cw
# qfX1c9EkdgZ2soyhE9zAw2lTEOMxiDFQXam9pUS9Plx6AP2CFMw+V4pMrLTaDrGY
# bCbkKzb/gQFdXxFXCESiudSCskWp69d3tC8KMxGQuamiHi/nea/d9Inf4k1f/f80
# t05mDbPnxJC2t9aSobcTCtxOgkILfZOXer9pV0S5unIDlLqVjlWrFYnYTj9suG0u
# Ul7w8+nDdfbchqG7UupuKZQ9Sa50pwIDAQABo4IB1TCCAdEwDAYDVR0TAQH/BAIw
# ADAOBgNVHQ8BAf8EBAMCB4AwPAYDVR0lBDUwMwYKKwYBBAGCN2EBAAYIKwYBBQUH
# AwMGGysGAQQBgjdhgqKNuwqmkohkgZH0oEWCk/3hbzAdBgNVHQ4EFgQUMb+ezyOn
# GXq1CbP4YZppjOiv/rgwHwYDVR0jBBgwFoAUpEMMf3ZapYXnPo0oDwwXokVpcMYw
# ZwYDVR0fBGAwXjBcoFqgWIZWaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0El
# MjAwMy5jcmwwdAYIKwYBBQUHAQEEaDBmMGQGCCsGAQUFBzAChlhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVy
# aWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDMuY3J0MFQGA1UdIARNMEswSQYEVR0g
# ADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wDQYJKoZIhvcNAQEMBQADggIBAENOz9kvF2O8
# AgdsAg69rzkqIsNHaQR5kuQOgtDi0yasd886PC4V33QwC0iv0hD8XBrPKUsKZt/6
# 6p0xtU1WZrnmROHIz3OlOyBu+pnWd2U8EMQ4+IROJCKwABOspLyEeKUqWY/NV59N
# 5rL9V/+4sB9d+5/DFl0Ct+6n5x6OqgjdPRYdkr7VxQJLWO9bM0wcWpLSZ4NotTWI
# b0ywMdLaeX/DvBM2sK/skOdnQ1MdFbyd8wC/g56Q8kz+6cHKZLvNGteY35/cgcFv
# xJIeCq/yzPBAjtnTufSg3QxaYtwac2shRHylLBVNobTcPIa1Js1CAwLF4iDAuiur
# jtR2a1tmTC5f5a4XhupucE2MLPTLVkpY/J0jLp95Pq0dU7lfB20LKVJDk05WD7BT
# 0GFasm0LM8NRioK3jsiSYtQWNLqBrogyE+F5bK7Rxwa/UXXElRNKJS9gcFB929TY
# 0jnlB/7cXpLMmeXB4tXq9pJNzETzMGSrfS2PhVWCvpqpiZoACiKEKvn616PolHgy
# HLZeAJJyUmH5w43LoRIhkC5aLENZdImVZ0ku5D4C1xHq5ZDJF0RAetMIA66bAZBg
# FHOOZeEKnzM9gZECuREzN7UCYyloY8nyhxhGPQnIS9LzPMq3DyiASMxlI+kKR8E7
# DyqLGvLfGcJdKxmWcY1gJ+txHFelKAl5MIIHKDCCBRCgAwIBAgITMwAAABgN65FV
# qYoAmAAAAAAAGDANBgkqhkiG9w0BAQwFADBjMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQg
# VmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMB4XDTI2MDMyNjE4MTEzMloX
# DTMxMDMyNjE4MTEzMlowWjELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0IElEIFZlcmlmaWVkIENT
# IEFPQyBDQSAwMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMiA2mA0
# VqKJ/ZVZ5Y/kjo+cVfEn+UHft8lHnkYK9HsYtkEyQGKNuIpXCCkEjfEzmd/jzjOc
# f+qdwn44KrrLeOCdBb5Hxl3tT7suOWuZyyRqXNJDSCEzESmcFbz8cezZXxknNCTo
# c/5IOxu+wvst2Uf947aXiaSeEMHCvRn9D3rpO8S2HlvyQLGPW+qJXhg22EsZGplH
# 27Z8r/IExa7zeno7i6jYR2D76AR7Dkgvu+eecoWqZKH9H288nLdYXVhxl7ABTHyx
# dk1SfHdmFWDn2XYumK0+LDMToUyoiypoS9V7czO4V3Zr+5YNkfpVsPJSJErvyYiD
# UNBgD3MMTLIEVw0j6fFVLOCW8vq7s9G42qBxXex/oQvHDz3KxAz9nhHWFEVZdGnI
# 5YooAq18EdOTRSc2I9zGYswxizyN5SM6J19U+NMivL9RXCfDF2WQrzlxl8EQxhn8
# ME07B2iY/jn1jWfyLMqRuGxr6niXD5xBXEBMEXH2CBHv0eGvJPscOak8u+Qm8Fnj
# BbgJbfZRPZIzIN7bycg5Teb6F8eVV4pwsFBzKblWhEOMhwJUju6qAZbY80wTRx96
# LzMLALLocKyywlYVLt6D9hsWGcBMlzJZ8yuQ24Bsx8w3w2mDxytLqNVWjDIPQYbn
# N2CL65BVxIr/rfyYDXERgremcihCA7T264MHAgMBAAGjggHcMIIB2DAOBgNVHQ8B
# Af8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFKRDDH92WqWF5z6N
# KA8MF6JFaXDGMFQGA1UdIARNMEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwEgYDVR0TAQH/BAgwBgEB/wIBADAf
# BgNVHSMEGDAWgBTZQSmwDw9jbO9p1/XNKZ6kSGow5jBwBgNVHR8EaTBnMGWgY6Bh
# hl9odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQl
# MjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDIxLmNy
# bDB9BggrBgEFBQcBAQRxMG8wbQYIKwYBBQUHMAKGYWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUy
# MENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcnQwDQYJKoZIhvcNAQEMBQAD
# ggIBAHHHIFb5fqaF1GJLAP08wxZwZQCfHn9BTCc29l0UYRf7gNEMiv1YKHgLzvAe
# 3D6WDUPe7MrXQOy09fQsUsEUALe9YxhfgiZfCguGhHTGU3yZR2isnduCekIla4jX
# nfVnWsLA+5StKQHF84gYOTenYQJvcej/EeLk9FJH85Sta5AfBeJpcxO5e7chEt7P
# BWRmkWY3BhEPntH03HYX/Izu3M5jQeHSEYJpgQrfz/oWtLRJdp1dbINQJ+flc4YA
# JGNQKcfH4lBQbR/hIcP6JuWkAjSCX5kedWZ1dfEdNl5NrQJgIiEXEo/b3bazSDrM
# uZ6JXXctZSa239QXtOtZekyLb/RQ2eJoOgfuuc8ZFXnFVfy5fLixmKLhqzDOo8zt
# jv6bNytqepnwSNmTmCMuFDcDaxlqmuU67wJpGbJ9wiJUfvNV+AC+bzUxZcXOIB/u
# bLtA6+fIQU8Z12rwxJ8+19HLD9Sre4foqmhok0h89gfp9x5lKLndFq3UD2CsTGrd
# E6OGFKlNxyG4Ei0Aw1U/Ggo1tSb6JH9fdeQv71ZCCKePId76FctyVjy8AZcUPWnj
# Q+owikBiyYQkEUpb11/j//U3mhAOv8Vj0gEmX+hJL3v2Lmu1Ps1nP0q9itoI9EEa
# zRALL6xa+BBrRygzvRAlUt5XCZLFQ7/Sh3TD1CvLttIuvEagMIIHnjCCBYagAwIB
# AgITMwAAAAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9N
# aWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBj
# MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQw
# MgYDVQQDEytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAy
# MDIxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpM
# SWxpCFUJtFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoE
# tuxACEGcgHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDp
# xDOxhgf8JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3
# bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF
# 9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+Hx
# KeJ9bYmPf6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK
# /H04kteZEZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0
# TnRJubL/hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0
# KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO
# 2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn
# +PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIB
# hjAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhq
# MOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEE
# AYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0
# eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0
# eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# SWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBB
# dXRob3JpdHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3Au
# bWljcm9zb2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1m
# CttXI0y6XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58
# HOcA1tcsHQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeA
# hBEjABvIUpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8B
# mQXv5hT2RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1E
# b59PYwISFCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrX
# SfyL2Op6mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+b
# Ha9KhTyzwdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8Hf
# FqNifN6+zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PX
# bjXzGifaIMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygb
# ahmYOHk7VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEok
# uPgNPa6EnTiOL60cPqfny+Fq8UiuZzGCGu0wghrpAgEBMHEwWjELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWlj
# cm9zb2Z0IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMwITMwAAxvhTHZeWGKAxAAAA
# AADG+DANBglghkgBZQMEAgEFAKCBtjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# Kld7dFLdvZygPQIm94QeWCWq09RhnYWpKs5R8/oLpjgwSgYKKwYBBAGCNwIBDDE8
# MDqgNIAyAFAAeQB0AGgAbwBuACAAMwAuADEANQAuADAAYgAxACAAKABmADMAMQBh
# ADgAOQBiACmhAoAAMA0GCSqGSIb3DQEBAQUABIIBgA5n/esClDchfh5tNq1Rl70K
# cKsFrjGryc+7Mxbn2ext/b4OSbIVGWfGjFUQrasLS2dEKn8vKZp9jUoKeau3519h
# S89yoN4HD5UnOk+QkLO7HVNPWk1iRLEEKwWMMO8jezzf1AU1ABa10gzX98awjB21
# AQUe/eB8VRf9AVSjSnSUTlUHShBr3d8vbwUIxTWqcuPPy5QaYx7AIwxpbngP1nYV
# JfaFcc6gBQaDFAhP+ePDQAx2WO8f8oego6CGTq1l13JOaaoUEoRoMEl6yeTshsGt
# Y8MqH8VNN5UgPOerg7G4fpfykMEqLJZobAkX1aSQAl8OPvbPmCV5oBcECuo+zjkU
# vBlf58KzpGgQm6P96syrdY+WPqOxu+P9VZsw2MLhouNv+K2M2TzWOvnisuhMK4v8
# adw/F0JRK9ql03agkpBiKIMfyABb3K7yGO/G9MNHysucMcYlXWx4Qs3pHzeb5Fj3
# 8aBoSUOsJOJvwx4I0EBUbHDhrM6YXKMtXcN8wO7lJKGCGBQwghgQBgorBgEEAYI3
# AwMBMYIYADCCF/wGCSqGSIb3DQEHAqCCF+0wghfpAgEDMQ8wDQYJYIZIAWUDBAIB
# BQAwggFiBgsqhkiG9w0BCRABBKCCAVEEggFNMIIBSQIBAQYKKwYBBAGEWQoDATAx
# MA0GCWCGSAFlAwQCAQUABCBARvMkO0Co84+a7ro08ZtWWldcLNwBfz5jMvN8a5nZ
# XQIGaeiBENGNGBMyMDI2MDUwNzE0NDQzOC4yODNaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046N0QwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABV2d1pJij5+OIAAAAAAFUwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjUxMDIz
# MjA0NjQ5WhcNMjYxMDIyMjA0NjQ5WjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL25H5IeWUiz9DAl
# Fmn2sPymaFWbvYkMfK+ScIWb3a1IvOlIwghUDjY0Gp6yMRhfYURiGS0GedIB6ywv
# uH6VBCX3+bdOFcAclgtv21jrpOjZmk4fSaT2Q3BszUfeUJa8o3xI7ZfoMY9dszTx
# HQAz6ZVX87fHGEVhQcfxW33IdPJOj/ae419qtYxT21MVmCfsTshgtWioQxmOW/vM
# C9/b+qgtBxSMf798vm3qfmhF6KCvFaHlivrM32hY16PGE3L0PFC+LM7vRxU7mTb+
# r76CeybvqOWk4+dbKYftPhV1t/E5S/6wwXeYmu/Y7JC7Tnh2w45G5Y4pcM3oHMb/
# YuPRdOWa0v+RC2QgmNVWqjuxDiylWscXQDuaMtb29AcdGUVV9ZsRY2M2sthAtOdZ
# OshiR5ufMtaHtiCkWv0jNfgUxrHurxzYuUNneWZ6EfQDgFAw8CSCKkSOK2c9jEop
# 4ddVq10xvbqxdrqMneVXvvIcXrPQAXj9j2ECpV2EwMb3Wnmpw00P78JpzPsk3Fs6
# 1ZvOGd/F1RcOBu6f2TWdp7HL7+rq7tgHr13MldbfIWu4lpoYYE1gTQa1Yrg5XN4j
# 7zs9klT2z3qocmPzV8DWQgIHNh+aTs7bujMEMQyI7Xt1zPxZCgcR6H0tmmzU/9Bx
# vsWbRalCQ2sYGyWupTdc4e7KY7kPAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUVgRf
# EG3cCAPwyL+pyRbKwdesZbYwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQBSHuGSVHvalCnFnlsqXIQefH1x
# P2SFr9g+Vz+f5P7QeywjfQb5jUlSmd1XnJUDPe/MHxL7r3TEElL+mNtG6CDPAytS
# tSFPXD9tTBtBMYh8Wqo64pH9qm361yIqeBH979mzWCkMQsTd0nM6dUl9B+7qiti+
# ToXwxIl39eYqLuYYfhD2mqqePXMzUKSQzkf73yYIVHP6nLJQz4aAmaWcfG9jg78s
# BkDV8KpW7JgktuLhphJEN1B+SVHjenPdcmrFXIUu/K4jK5ukfWaQIjuaXzSjBlNj
# C5tQN6adPfA3GxUwHPeR4ekL5If/9vBf13tmzBW+gy+0sNGTveb9IL9GU8iX8Uvy
# wsX62nhCCPRUhTigDBKdczRUrNrntBhowbfchBDFML8avRMRc9Gmc2JvIryX336S
# FQ51//q1UU2HMSJEMhWLJSIWJVhfUowsOa+PampIzETYfFvTu2mqKJUlWZXkGYxr
# dCvCczJcqeoadpW1ul6kcdnDh228SQ8ZhDc6IRlM4iNd5SNoNgX+aom3wuGyjUaS
# aPZWxPB1G2NKiYhPLt0lPHg0Gskj1zhISY8UQkMMDr3o2JgRuT+wnJEDQUp55ddv
# hSkSoD6I9DL/s+TjIY/c9jLaW5xywJHqdKHUApRMsghv7kebSua1upmR+TquelFk
# tDSOjVdSRkuya4uoxTGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABV2d1pJij5+OIAAAAA
# AFUwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDUwNzE0NDQz
# OFowLwYJKoZIhvcNAQkEMSIEICkjClr3KEKngCzQP/kwqnpyeGk2zSKJjz5t5mxf
# zlnuMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg2Lk8l2SGYru/ff7+D2qr
# JnkswcYdK6pGKu7GGGr4/s0wfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABV2d1pJij5+OIAAAAAAFUw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# HTtUAYJlv7bgWVeRBo4X7FeHDeqgZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDt
# psXwMCIYDzIwMjYwNTA3MDgwNDAwWhgPMjAyNjA1MDgwODA0MDBaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAO2mxfACAQAwCgIBAAICLY8CAf8wBwIBAAICEm0wCgIF
# AO2oF3ACAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAoNYHO8mXdHOy3Mgy
# 6WbnU+TlNyjh+8Cr5Ofqijf3rienBKhcxjsdEGwotHFv1hwCuul09LBb6wfnmac0
# x2MWUmweKmk8fsE8nH8K2A8m75R9aOmk6cG32DGPTmLQwNM4r0QfyJknqN+EE9Xd
# mQU8KzlAODzPpRwotSoAxpaAcxJRLOsAKCIekrqYAkQoUJmu7YFKvLHGW/tdRBxm
# cogI7P5vCiteFkTVkvjEUFLk8K3AIaK6TCJzeBlFo8Ef15NpU85ZwwgsM82R+1tZ
# fxclLomSG7q9YUggFC4vlvOGoQ7KgqaNf2q3b4O2prBq1sh7UWZuFybSH+zNTCzi
# 4XZvPDANBgkqhkiG9w0BAQEFAASCAgBInspS0si7cQ7ekc9x9qNeorBqwYWYD5OU
# oWGgDmscrrW57roy/XP48j1esGJZcMnHJU78unIUBv4s5uNrLbDcztoS6nl4KyR6
# ZQMHyGslUSV+pe6oQlkQRIFFJOvlx+7UpQBMf1e6MkFvoKmAPU9p96vP60p22tfw
# Nd0kCpVazNVpbfMHGM8hQQXZtuaMm/zvxPNhcEOLayftMVB2P/P0EtUvuBTjncx7
# jJAKZSlHUaz5PmQHCU4uM6pxeiBgv4J+Tzkm0HO5FQd+Ok4X3HWbluyifqnoCb0W
# +SDlmrSqrPXkNVV7vlM0vUw5BXyxLd2Lobq8ggNgiauNp+xLe2QK5vQR/Oz3AmDx
# rbr56vB6Ovmin39E21vpGUR7fk9ktL5B+mETo5HYMEG7WpiOOWhQEt07dTIEx0/Y
# bP9eR4gepbHAo72YxVpz9Y2GIh+a3OR1xt4yYmOhIo4g1JvvzpGQOQfG7tLn0WRD
# rGg8zueTIMsJbOfWArLjOpottOfheijle9xJqZ4i0ya+2kdjb2zEZnBIECzOEr1K
# wa9V3tOeFNdcK12bYt3StuEf6YT2jTqMJwdrrKnvs7Dq8swK+Ss2z2DVC07MJ2qd
# 7Lptt+Z/ejNm0ELZU2bAhyqRWliTIkNujNgAsmWwNtFmQq5ZtKMGlaSxYbUBZd3/
# zSyBlmPuyg==
# SIG # End signature block
