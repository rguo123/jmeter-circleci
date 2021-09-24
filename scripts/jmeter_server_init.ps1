# ------------------------------------------------------
# Start listening
# ------------------------------------------------------
Start-Job -ScriptBlock { & C:\JMeter\apache-jmeter-5.4\bin\jmeter-server.bat -J server.rmi.ssl.disable=true }
