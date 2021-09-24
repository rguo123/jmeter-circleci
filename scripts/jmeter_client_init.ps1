# ------------------------------------------------------
# Preparation
# ------------------------------------------------------
$jmeterBin = "C:\JMeter\apache-jmeter-5.4\bin\jmeter.bat"
$jmeterTestPlan = "C:\JMeter\sample.jmx"

# ------------------------------------------------------
# Start testing
# ------------------------------------------------------
& $jmeterBin -n -J server.rmi.ssl.disable=true -t $jmeterTestPlan -R $args[0] -J target_hostname=$args[1]
