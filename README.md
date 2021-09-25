# jmeter-circleci [![CircleCI](https://circleci.com/gh/phongcao/jmeter-circleci/tree/main.svg?style=svg)](https://circleci.com/gh/phongcao/jmeter-circleci/tree/main)

A sample project about running Apache JMeter with CircleCI.

The pipeline does the following jobs:

- Build, test and package a sample .NET Core web app.
- Spin up an Azure function and deploy the web app's package to it.
- Spin up two Azure virtual machines and use PowerShell script to install Java and JMeter on them.
- Start JMeter distributed tests by using those two virtual machines: one acts as a server and one acts as a client.
- Clean up all provisioned resources.
