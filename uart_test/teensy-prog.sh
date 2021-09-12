#!/bin/bash

arduino --verbose --board teensy:avr:teensy40:usb=serial --upload uart_test.ino --pref build.path=build
