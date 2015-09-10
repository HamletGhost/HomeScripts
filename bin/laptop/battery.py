#!/usr/bin/env python2

import sys, os
import logging

BatteryInfoDir = '/sys/class/power_supply'

def TimeLeft(BatterySysPath):
    if not os.path.isdir(BatterySysPath):
        raise RuntimeError("No battery information at '%s'" % BatterySysPath)
    
    CurrentChargeFile = os.path.join(BatterySysPath, 'charge_now')
    FullChargeFile = os.path.join(BatterySysPath, 'charge_full')
    CurrentFile = os.path.join(BatterySysPath, 'current_now')
    TypeFile = os.path.join(BatterySysPath, 'type')
    PSUNameFile = os.path.join(BatterySysPath, 'model_name')

    try:
        CurrentCharge = int(open(CurrentChargeFile, 'r').readline())
    except IOError:
        logging.debug("No current charge information available ('%s')",
            CurrentChargeFile)
        raise
    # try

    try:
        FullCharge = int(open(FullChargeFile, 'r').readline())
        if FullCharge == 0: ChargeLeft = None
        else: ChargeLeft = float(CurrentCharge)/FullCharge
    except IOError:
        FullCharge = None
        ChargeLeft = None
    # try

    try:
        Current = int(open(CurrentFile, 'r').readline())
        if Current == 0: SecondsLeft = -1
        else: SecondsLeft = float(CurrentCharge)/Current * 3600.
    except IOError:
        Current = None
        SecondsLeft = None
    # try
    
    try:
        PSUName = open(PSUNameFile, 'r').readline().strip()
    except IOError: PSUName = DirName

    try:
        TypeName = open(TypeFile, 'r').readline().strip()
    except IOError: TypeName = "Power supply"

    Name = "%s `%s'" % (TypeName, PSUName)
    
    return ChargeLeft, SecondsLeft, Name

# TimeLeft()


def SecondsToString(seconds):
    s = []
    if seconds >= 3600:
        hours = int(seconds/3600.)
        s.append(str(hours) + "h")
        seconds -= hours * 3600
    if seconds >= 60:
        minutes = int(seconds/60.)
        s.append(str(minutes) + "'")
        seconds -= minutes * 60
    s.append(str(int(seconds)) + '"')
    return " ".join(s)    
# SecondsToString()


if __name__ == "__main__":
    nBatteries = 0
    if os.path.isdir(BatteryInfoDir):
        for DirName in os.listdir(BatteryInfoDir):
            BatteryInfoPath = os.path.join(BatteryInfoDir, DirName)
            if not os.path.isdir(BatteryInfoPath): continue

            try:
                ChargeLeft, SecondsLeft, Name = TimeLeft(BatteryInfoPath)
            except: continue
            
            print Name,
            if ChargeLeft is not None:
                print "(%.1f%% full)" % (ChargeLeft * 100.),
            if SecondsLeft is None:
                print "does not report current consumption.",
            elif SecondsLeft >= 0:
                print "has %s left (at the current usage rate)." % SecondsToString(SecondsLeft),
            else:
                print "has no charge limit.",

            print
            nBatteries += 1
        # for
    # if

    if nBatteries == 0:
        logging.error("No battery information found in '%s'.",
            BatteryInfoDir)
        sys.exit(1)
    # if no batteries
    sys.exit(0)    
# main
