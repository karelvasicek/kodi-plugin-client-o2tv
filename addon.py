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

addonID = 'plugin.video.client-o2tv'
addon = xbmcaddon.Addon(addonID)
addonName = addon.getAddonInfo('name')
icon = addon.getAddonInfo('icon')

addonDir = addon.getAddonInfo('path').decode('utf-8')
libDir = os.path.join(addonDir, 'resources', 'lib')
addonDataDir = os.path.join(xbmc.translatePath('special://userdata/addon_data').decode('utf-8'), addonID)
configFile = os.path.join(addonDataDir, 'config.json')

def getLocaleString(id):
    return addon.getLocalizedString(id).encode('utf-8')

def createConfig():
    config = {
        'provider': 'o2tv.cz',
        'username': addon.getSetting('username'),
        'password': addon.getSetting('password'),
        'device_name': addon.getSetting('device_name'),
        'device_type': 'STB',
        'device_id': addon.getSetting('device_id'),
        'resolution': 'HD',
        'streaming_protocol': 'HLS',
        'parse_stream': '0',
        'insert_logo': '1',
        'ffmpeg': '/usr/bin/'
    }
    with open(configFile, 'w') as f:
        f.write(json.dumps(config))

def Login():
    Exec('login.sh', getLocaleString(30101))

def Playlist():
    Exec('playlist.sh', getLocaleString(30102))

def Exec(cmd, message):
    # xbmc.log(cmd, level=xbmc.LOGNOTICE)
    createConfig()
    cmd = os.path.join(libDir, cmd)
    # cmd = os.path.join(libDir, 'test.sh')
    os.chmod(cmd, 0775)
    os.system(cmd)
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
