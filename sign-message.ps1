# Runtime variables
$ipbind = "26604"
$comport = 1
$displaylength = 40
$displaylengthminus1 = $displaylength - 1
$alerttime = 30
$blank = ""
for ($i = 1; $i -le $displaylength; $i++) {
		$blank = $blank + " "
}

# Make sure running as admin
if (-not [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
	Write-Host "Must be run as admin"
	exit
}

# Check if the firewall port is open and add the rule if not
if ($(netsh advfirewall firewall show rule name="SIGN_HTTP_LISTENER") -match "No rules") {
	netsh advfirewall firewall add rule name="SIGN_HTTP_LISTENER" protocol=TCP dir=in localport=$ipbind action=allow
	Write-Host "Firewall rule added"
}

# Open up the COM port
$port = New-Object System.IO.Ports.SerialPort COM$comport,9600,None,8,one
try {
	$port.open()
	$open = $true
} catch {
	Write-Host "The port is closed, it may be in use or not exist"
	exit
}
Write-Host "Port opened"

# Clear screen
$port.write("`r$blank")  # Take it from the top


# Start HTTP listening
$httpListener = New-Object System.Net.HttpListener
$httpListener.Prefixes.Add("http://+:$ipbind/")
$httpListener.Start()
Write-Host "HTTP listener started"

while($httpListener.IsListening) {
	# Receive HTTP GET request and return 200
	$httpListenerContext = $httpListener.GetContext()
	$message = $httpListenerContext.Request.RawUrl

	# Convert ascii hex codes back to text
	# Initialise as arrays
	$hex = @()
	$text = @()

	# Split into separate arrays for ascii codes and text
	$message.Split("%") | forEach {
		$hex += $_.substring(0,2)
		$text += $_.substring(2)
	}

	# Remove "/?" from start of message
	$hex = $hex[1..$hex.length]
	$message = ""

	# Convert hex to ascii and join back together
	for ($i = 0; $i -lt $hex.length; $i++) {
		$hex[$i] = [char]([convert]::toint16($hex[$i],16))
		$message = $message + $text[$i] + $hex[$i]
	}
	# Aaaand the last one
	$message = $message + $text[-1]
	Write-Host $message

	# Send the response
	$httpResponse = $httpListenerContext.Response
	$httpResponse.Close()

	# Windows notification
	Start-Job -ScriptBlock {
		param($message)
		Add-Type -AssemblyName System.Windows.Forms
		$global:balmsg = New-Object System.Windows.Forms.NotifyIcon
		$path = (Get-Process -id $pid).Path
		$balmsg.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
		$balmsg.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
		$balmsg.BalloonTipText = $message
		$balmsg.BalloonTipTitle = "Package Alert"
		$balmsg.Visible = $true
		$balmsg.ShowBalloonTip(10000)
		Start-Sleep -s 10
		$balmsg.Visible = $false
	} -ArgumentList $message

	# Writing message
	# If the character at half the screen isn't a space, non-existent or a -, break it
	if ($message[$displaylength/2] -ne " " -and $message[$displaylength/2] -ne $null -and $message[$displaylength/2-1] -ne "-") {
		for ($i=$displaylength/2; $i -gt 0; $i--) {
			# Work backwards to find the closest space
			if ($message[$i] -eq " " -or $message[$i] -eq "-") {
				$break = $i
				# Split the string at the space
				$str1 = -join $message[0..$break]
				$str1 = $str1.trim()
				$str2 = -join $message[$break..$message.length]
				$str2 = $str2.trim()
				# Adds a buffer of spaces to the start of str1
				$buffer = [Math]::Floor([decimal](($displaylength/2-$str1.length)/2))
				for ($i = 0; $i -lt $buffer; $i++) {
					$str1 = " " + $str1
				}
				# Pad str1 to the end of the line
				for ($i=$str1.length; $i -lt $displaylength/2; $i++) {
					$str1 = $str1 + " "
				}
				# Adds a buffer of spaces to the start of str2
				$buffer = [Math]::Floor([decimal](($displaylength/2-$str2.length)/2))
				for ($i = 1; $i -le $buffer; $i++) {
					$str2 = " " + $str2
				}
				# Append the strings
				$message = $str1 + $str2
				break
			}
		}
	} else {
		# Adds a buffer of spaces to the start of the string to centre it
		$buffer = [Math]::Floor([decimal](($displaylength/2-$message.length)/2))
		for ($i = 1; $i -le $buffer; $i++) {
			$message = " " + $message
		}
	}

	# Trims the length of the string to screen size
	if ($displaylength -lt $message.length) {
		$message = -join $message[0..$displaylengthminus1]
	}
	# Adds blank characters to the end of screen
	for ($i = $message.length; $i -lt $displaylength; $i++) {
		$message = $message + " "
	}

	# Prints and flashes string
	for ($i = 1; $i -le $alerttime; $i++) {
		$port.write($message)
		Start-Sleep -m 500
		$port.write($blank)
		Start-Sleep -m 500
	}
}
