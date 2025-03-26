$Servers = ("192.168.1.1", "localhost")

$Ports = (22,80,135)

$Out = "C:\Users\Public\TCPResults.csv"

if (!(Test-Path $Out)) {
    "Date,SourceHost,SourceIP,DestHost,DestIP,DestPort,TCPTest" | Out-File -FilePath $Out -Encoding ascii
}

ForEach ($Server in $Servers)  {

    foreach ($Port in $Ports) {
       
        $TCPResults = Test-NetConnection -ComputerName $Server -port $Port -WarningAction SilentlyContinue

        $Date = (Get-Date)
        $HostName = $env:COMPUTERNAME
        $HostIP = ($TCPResults.SourceAddress).IPAddress
        $DestHostName = $TCPResults.ComputerName
        $DestIP = $TCPResults.RemoteAddress
        $DestPort = $TCPResults.RemotePort
        $TcpTest = $TCPResults.TcpTestSucceeded
        
        $OutPut = "$Date,$HostName,$HostIP,$DestHostName,$DestIP,$DestPort,$TcpTest" 
        
        Add-Content -Path $Out -Value $OutPut -Encoding ascii
    }
}

Invoke-Item $Out
