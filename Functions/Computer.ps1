
function Invoke-ComputerHybernate {
    shutdown.exe /h
}
Set-Alias HybernateComputer Invoke-ComputerHybernate


function Invoke-ComputerShutdown {
    shutdown.exe /s /t 0
}
Set-Alias ShutdownComputer Invoke-ComputerShutdown


function Invoke-ComputerRestart {
    shutdown.exe /r /t 0
}
Set-Alias RestartComputer Invoke-ComputerRestart

function Invoke-ComputerSleep {
    psshutdown.exe -d -t 0
}
Set-Alias SleepComputer Invoke-ComputerSleep