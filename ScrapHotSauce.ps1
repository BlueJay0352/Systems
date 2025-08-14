# Scrapes Web Page looking for restock of hotsauce at Fallow.
# Email notification if hotsauce is in stock

# Set email creds
function Send-YahooNotify {
    param (
        [string]$To = "jayvet05@yahoo.com",
        [string]$Subject = "Fallow HotSauce In Stock",
        [string]$Body,
        [string]$user_pass = "$env:USERPROFILE\yahoo.txt",
        [string]$user_email = "jayvet05@yahoo.com"
    )

    $secure_pass = Get-Content $user_pass | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential ($user_email, $secure_pass)

    try {
        Send-MailMessage -From $user_email -To $To -Subject $Subject -Body $Body `
            -SmtpServer "smtp.mail.yahoo.com" -Port 587 -UseSsl -Credential $cred
        Write-Host "Email sent to $To successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to send email: $_"
    }
}

# Scrap site content
    try {
        $scraped = (Invoke-WebRequest -Uri "https://shop.fallowrestaurant.com/").Content
    } catch {
        Write-Error "A connection error occurred: $($_.Exception.Message)"
        exit
    }

# Match pattern for hotsauce elements
$regExp = '(?i)(?=.*handcrafted)(?=.*btn).*'
$matchedHREF = [regex]::Matches($scraped, $regExp)

# Save each URL after href=
foreach ($matchHREF in $matchedHREF) {
    $urlRegExp = 'href="([^"]+)"'
    $urlMatches = [regex]::Matches($matchHREF, $urlRegExp)

    foreach ($url in $urlMatches) {
        # Regex extract only part inside quotes
        $endURL = $url.Groups[1].Value 
        $urlConstruct = "https://shop.fallowrestaurant.com" + $endURL  
    } 

    # Check if available to add to cart
    if ( $matchHREF -match "Add" ) {
        Send-YahooNotify -Body "$urlConstruct"
            
    } else {
        Write-Host $urlConstruct "Sold Out" -ForegroundColor Red 
    }
    
}
