# -*- coding: utf-8 -*-
# code by charles (https://github.com/karel_vasicek/kodi-plugin-client-o2tv)

import sys
import urllib
import urlparse
import xbmcgui
import xbmcplugin
import xbmcaddon
import xbmc
import os
import json
import subprocess

addonID = 'plugin.video.client-o2tv'
addon = xbmcaddon.Addon(addonID)
addonName = addon.getAddonInfo('name')
icon = addon.getAddonInfo('icon')

addonDir = addon.getAddonInfo('path').decode('utf-8')
libDir = os.path.join(addonDir, 'resources', 'lib')
addonDataDir = os.path.join(xbmc.translatePath('special://userdata/addon_data').decode('utf-8'), addonID)
settingsFile = os.path.join(libDir, 'settings.sh')

def getLocaleString(id):
    return addon.getLocalizedString(id).encode('utf-8')

def createSettings():
    with open(settingsFile, 'w') as f:
        f.write('#!/bin/sh\n')
        f.write('username="{0}"\n'.format(addon.getSetting('username')))
        f.write('password="{0}"\n'.format(addon.getSetting('password')))
        f.write('device_name="{0}"\n'.format(addon.getSetting('device_name')))
        f.write('device_id="{0}"\n'.format(addon.getSetting('device_id')))
        f.write('data="{0}/"\n'.format(libDir))
        f.write('cd "{0}"\n'.format(libDir))
    os.chmod(settingsFile, 0775)

def Login():
    Exec('login.sh', getLocaleString(30101))

def Playlist():
    Exec('playlist.sh', getLocaleString(30102))

def Exec(cmd, message):
    xbmc.log(cmd, level=xbmc.LOGNOTICE)
    createSettings()
    cmd = os.path.join(libDir, cmd)
    # cmd = os.path.join(libDir, 'test.sh')
    os.chmod(cmd, 0775)
    os.system(cmd + ' ' + libDir)
    xbmc.executebuiltin('Notification(' + addonName + ',' + message + ',5000)')

base_url = sys.argv[0]
addon_handle = int(sys.argv[1])
args = urlparse.parse_qs(sys.argv[2][1:])
mode = args.get('mode', ['0'])
mode = mode[0]

if mode == '1':
    Login()
elif mode == '2':
    Playlist()
