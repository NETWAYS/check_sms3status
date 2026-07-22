check_sms3status
================

This plugin checks the status of an SMS modem using the regular_run functionality
provided in smstools3

It does not directly access the modem, but instead reads a status file generated
by smstools3.

In order to work the following options need to be set in smsd.conf

    regular_run_interval = 60
    regular_run_cmd = AT+CREG?;+CSQ;+COPS?
    regular_run_statfile = F<status_file>


### Requirements

* Perl library: `Nagios::Plugins utils.pm`
    
### Usage

    check_sms3status [options] status_file

    --warning
        warning level for percentage signal strength (default 40)

    --critical
        critical level for percentage signal strength (default 20)

    --timeout
        how long to wait for the file (default 30)

    --age
        the maximum age of the file in seconds (default 300)

