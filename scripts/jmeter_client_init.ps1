# ------------------------------------------------------
# Preparation
# ------------------------------------------------------
$jmeterBin = "C:\JMeter\apache-jmeter-5.4\bin\jmeter.bat"
$jmeterTestPlan = "C:\JMeter\sample.jmx"

# ------------------------------------------------------
# Start testing
# ------------------------------------------------------
& $jmeterBin -n -J server.rmi.ssl.disable=true -t $jmeterTestPlan -J target_hostname=$args[1] -R $args[0]
