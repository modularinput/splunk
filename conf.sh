#!/bin/bash

# Splunk conf discovery script
# ljc Nov 08 2022

# Check to make sure user is root. 
# Too many potential issues (unseen files etc...) if not run as root user.
if [[ $(whoami) != "root" ]]; then
    echo "User is not root. Exiting..."
    exit
fi

# Check for valid Splunk directory. 
if [[ -d /opt/splunk/etc ]]; then
    # enterprise
    path="/opt/splunk/etc"
elif [[ -d /opt/splunkforwarder/etc ]]; then
    # splunkforwarder
    path="/opt/splunkforwarder/etc"
else
    echo ""
    echo "Could not find a valid Splunk directory. Exiting..."
    echo ""
    exit
fi

################################
### Argument 1 Setup - Start ###

# Variable setup:

# Collect a list of valid splunk configuration files. 
confs=$(find $path -name "*.conf" | awk -F "/" '{print $NF}' | sort | uniq | awk -F "." '{print $1}')

# Capture the last splunk configuration term from the "$confs" array variable. 
conf_example=$(echo "$confs" | grep -P "^.*$" | tail -n 1)

# Assign an alias for bash shell argument 1
arg1=$1

# Set Empty String
conf_state=""

# Conf function message
conf_message() {
    echo ""
    echo "Valid conf arguments:"
    echo ""
    echo "$confs"
    echo ""
    echo "Expecting valid conf argument. Exiting..."
    echo "Example: ./conf.sh $conf_example"
    echo ""
} 

# Change conf_state if user input is valid. 
for conf in ${confs[@]}; do
    # echo "$conf == $arg1" 
    if [[ $conf == $arg1 ]]; then
        conf_state="pass"  
    fi  
done

# Make sure conf_state is not empty.
if [[ -z $conf_state ]]; then
    conf_message
    exit
fi 

if [[ -n $conf_state ]]; then
    echo ""
    echo "Splunk file locations: $arg1.conf"
    echo "find $path -name "*.conf" | grep -P \"$arg1.conf\""
    echo ""
    files=$(find $path -name "*.conf" | grep -P $arg1.conf)
    for file in ${files[@]}; do
        ls -la $file
    done
    echo ""
fi

### Argument 1 Setup - End ###
##############################


################################
### Argument 2 Setup - Start ###

# Variable setup:

# Collect a list of valid splunk configuration file stanzas. 
stanzas=$(sudo -u splunk -i splunk btool $arg1 list | grep -P "\[.*?\]")

# Capture the last splunk stanza term from the "$stanzas" array variable. 
stanza_example=$(echo $stanzas | grep -oP "\[\K." | tail -n 1)

# Assign an alias for bash shell argument 2
arg2=$2

# Set Empty String
stanza_state=""


# Stanza function message
stanza_message() {
    echo "btool $arg1 configurations:" 
    echo "sudo -u splunk -i splunk btool $arg1 list"
    echo ""
    echo "show config $arg1 configurations:" 
    echo "sudo -u splunk -i splunk show config $arg1"
    echo ""
    echo "List of $arg1 Stanzas:"
    echo ""
    echo "$stanzas"
    echo ""
    echo "To list all stanzas starting with '$stanza_example' in $arg1.conf run: ./conf.sh $arg1 $stanza_example"
    echo ""
}

# Change stanza_state if user input is valid. 
for stanza in ${stanzas[@]}; do
    stanza=$(echo "$stanza" | sed 's/\[\(.*\)\]/\1/g')
    # echo ""
    # echo "Stanza: $stanza" 
    # echo "Bash if regex conditional: $stanza =~ ^$arg2.*?"
    # Note: If arg2 is empty the regex will match anything.
    if [[ -n $arg2 ]] && [[ "$stanza" =~ ^$arg2.*? ]]; then
        # echo "Matched"
        stanza_state="pass" 
    fi
done 

# Make sure conf_state is not empty.
if [[ -z $stanza_state ]]; then
    stanza_message
    exit
fi 

### Argument 2 Setup - End ###
##############################


################################
### Argument 3 Setup - Start ###

# Variable setup:

# Assign an alias for bash shell argument 3
arg3=$3

# Filter function message
filter_message() {
    echo "Filter stanza results further with third argument: ./conf.sh $arg1 $stanza_example <filter>"
    echo ""
}

### Argument 3 Setup - End ###
##############################


################################
### Core Logic - Start ###

if [[ -n $stanza_state ]] && [[ -z $arg3 ]]; then
    # What we run if there is no argument 3.
    echo "splunk btool:"
    echo "sudo -u splunk -i splunk btool $arg1 list $arg2 --debug"
    echo ""
    sudo -u splunk -i splunk btool $arg1 list $arg2 --debug
    key1=$(sudo -u splunk -i splunk btool $arg1 list $arg2 --debug | grep -P "(sslPassword\s*?=\s*?|pass4SymmKey\s*?=\s*?)")

    echo ""
    echo "splunk show config:"
    echo "sudo -u splunk -i splunk show config $arg1 | awk \"/\[$arg2.*?\]/,/^$/\""
    echo ""
    sudo -u splunk -i splunk show config $arg1 | awk "/\[$arg2.*\]/,/^$/"
    key2=$(sudo -u splunk -i splunk show config $arg1 | awk "/\[$arg2.*\]/,/^$/" | grep -P "(sslPassword\s*?=\s*?|pass4SymmKey\s*?=\s*?)")

    if [[ -n $key1 ]] || [[ -n $key2 ]]; then
        echo "Decrypt Key(s):"
        echo "Note: Must be splunk user to see correct decrypted value."
        echo "su splunk"
        echo "splunk show-decrypted --value 'key value'"
        echo ""
    fi

    filter_message

elif [[ -n $stanza_state ]] && [[ -n $arg3 ]]; then
    # What we run if there is an argument 3.
    echo "splunk btool:"
    echo "sudo -u splunk -i splunk btool $arg1 list $arg2 --debug | grep -iP \"(\[$arg2.*?\]|^.*?\.conf\s.*?$arg3.*?$)\"" 
    echo ""
    sudo -u splunk -i splunk btool $arg1 list $arg2 --debug | grep -iP "(\[$arg2.*?\]|^.*?\.conf\s.*?$arg3.*?$)"
    key1=$(sudo -u splunk -i splunk btool $arg1 list $arg2 --debug | grep -iP "(\[$arg2.*?\]|^.*?\.conf\s.*?$arg3.*?$)" | grep -P "(sslPassword\s*?=\s*?|pass4SymmKey\s*?=\s*?)")
    echo ""
    echo "splunk show config:"
    echo "sudo -u splunk -i splunk show config $arg1 | awk \"/\[$arg2.*\]/,/^$/\" | grep -iP \"(\[$arg2.*?\]|$arg3.*?$)\""
    echo ""
    sudo -u splunk -i splunk show config $arg1 | awk "/\[$arg2.*\]/,/^$/" | grep -iP "(\[$arg2.*?\]|$arg3.*?$)"
    key2=$(sudo -u splunk -i splunk show config $arg1 | awk "/\[$arg2.*\]/,/^$/" | grep -iP "(\[$arg2.*?\]|$arg3.*?$)" | grep -P "(sslPassword\s*?=\s*?|pass4SymmKey\s*?=\s*?)")
    echo ""
    echo $key1
    echo $key2
    if [[ -n $key1 ]] || [[ -n $key2 ]]; then
        echo ""
        echo "Decrypt Key(s):"
        echo "Note: Must be splunk user to see correct decrypted value."
        echo "su splunk"
        echo "splunk show-decrypted --value 'key value'"

    fi
    echo ""
fi
