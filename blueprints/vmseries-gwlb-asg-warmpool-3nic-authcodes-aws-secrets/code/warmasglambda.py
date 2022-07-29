from ast import AsyncFunctionDef
import boto3
import botocore
import time
import re
from datetime import datetime
import json
import urllib.request
import urllib.error
import ssl
import xmltodict

def log(message):
    print('{}Z {}'.format(datetime.utcnow().isoformat(), message))

def check_panorama_job_status(p,key,jid,serial):
    e = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    while not e:
            url = "https://" + p + "/api/?type=op&cmd=<show><jobs><id>" + str(jid) + "</id></jobs></show>"
            cmd = urllib.request.Request(url + "&key=" + key)
            urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
            response = urlcall.read()
            job_status_dict = xmltodict.parse(response)
            if job_status_dict['response']['@status'] == "success":
                if job_status_dict['response']['result']['job']['progress'] == '100':
                    if serial != "" and job_status_dict['response']['result']['job']['devices']['entry']['serial-no'] == serial and \
                        job_status_dict['response']['result']['job']['devices']['entry']['result'] == "OK":
                        e = True
                        log("Job " + jid + " complete for " + serial)
                        return(True)
                    elif serial == "" and job_status_dict['response']['result']['job']['result'] == "OK":
                        e = True
                        log("Job " + jid + " complete")
                        return(True)
            if not e:
                time.sleep(5)

def check_panorama(p1,p2,key):
    r = { "panorama": "",
          "panorama_app_version": "",
          "panorama_av_version": ""}
    p = p1
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    while True:
        url = "https://" + p + "/api/?type=op&cmd=<show><system><info></info></system></show>"
        cmd = urllib.request.Request(url + '&key=' + key)
        log("check_panorama: system URL:" + url)
        try:
            urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
            response = urlcall.read()
            system_info_dict = xmltodict.parse(response)
        except urllib.error.URLError as e:
            log("check_panorama: URLError: " + str(e) + " - " + url)
            if p == p1:
                log("panorama system info: FAIL for " + p1 + ". " + "Trying " + p2)
                if (p2 != ""):
                    p = p2
            elif p == p2:
                log("panorama system info: FAIL for " + p2 + ". " + "Trying " + p1)
                p = p1
            time.sleep(30)
            continue
            
        if system_info_dict['response']['@status'] == "success":
            r['panorama'] = p

            url = "https://" + p + "/api/?type=op&cmd=<request><batch><content><info></info></content></batch></request>"
            cmd = urllib.request.Request(url + '&key=' + key)
            log("check_panorama: content URL:" + url)
            urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
            response = urlcall.read()
            content_info_dict = xmltodict.parse(response)
            
            log("check_panorama: <request><batch><content><info></info></content></batch></request>: " + str(content_info_dict))
            if content_info_dict['response']['@status'] == "success":
                for e in content_info_dict['response']['result']['content-updates']['entry']:
                    if (e['version'] != None and e['downloaded'] != None and e['current'] != None and \
                        e['downloaded'] == "yes" and e['current']):
                        r['panorama_app_version'] = e['version']
                        break
            if r['panorama_app_version']!= None:
                log("check_panorama: SUCCESS: Found apps-threats version: " + r['panorama_app_version'])
            else:
                log("check_panorama: ERROR: Did not find downloaded and current content version: ")

            url = "https://" + p + "/api/?type=op&cmd=<request><batch><anti-virus><info></info></anti-virus></batch></request>"
            cmd = urllib.request.Request(url + '&key=' + key)
            log("check_panorama: content URL:" + url)
            urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
            response = urlcall.read()
            av_info_dict = xmltodict.parse(response)
            
            log("check_panorama: <request><batch><anti-virus><info></info></anti-virus></batch></request>: " + str(av_info_dict))
            if av_info_dict['response']['@status'] == "success":
                for e in av_info_dict['response']['result']['content-updates']['entry']:
                    if (e['version'] != None and e['downloaded'] != None and e['current'] != None and \
                        e['downloaded'] == "yes" and e['current']):
                        r['panorama_av_version'] = e['version']
                        break
            if r['panorama_av_version']!= None:
                log("check_panorama: SUCCESS: Found anti-virus version: " + r['panorama_av_version'])
            else:
                log("check_panorama: ERROR: Did not find downloaded and current content version: ")
            return r
        else:
            log("check_panorama: Panorama did not receive API request successfully. Sleeping for 30")
            time.sleep(30)


def check_dg(p,key,iid,dg,content_version,av_version):
    r = { "push_app": True,
          "push_av": True,
          "push_dg": True,
          "serial_number": "" }
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE    
    # Make sure EC2 Instance is in list of managed devices in Panorama and connected and check DG Sync Status
    log("looking for " + iid + " on " + p + ":" + dg)
    url = "https://" + p + "/api/?type=op&cmd=<show><devicegroups><name>" + dg + "</name></devicegroups></show>"
    log("check_dg: URL: " + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    devices_dg_dict = xmltodict.parse(response)
    log("check_dg: " + str(devices_dg_dict))
    # Need better error checking.  What if no devices in Device Group?
    if devices_dg_dict['response']['@status'] == "success":
        d_candidate = {}
        if "devices" in devices_dg_dict['response']['result']['devicegroups']['entry']:
            d = devices_dg_dict['response']['result']['devicegroups']['entry']['devices']['entry']
            # single device in DG on panorama - struct is dict
            if isinstance(d, dict):
                if 'hostname' in d:
                    d_candidate = d
            # multiple devices in DG on panorama - struct changes is list of dict
            elif isinstance(d, list):
                for device in d:
                    if 'hostname' in device and device['hostname'] == iid:
                        d_candidate = device
            else:
                log("check_dg: FAIL: was expecting dict 1 device or list of dict 2 devices not: " + str(devices_dg_dict))
        else:
            #  no devices found in DG on Panorama
            log("check_dg: FAIL: No Devices in Device Group: " + str(devices_dg_dict))
            return r

        if 'hostname' in d_candidate and d_candidate['hostname'] == iid:
            r['serial_number'] = d_candidate['@name']

            if d_candidate['av-version'] == av_version:
                log("Panorama and VM have same Anti-Virus: " + av_version + " : " + iid + " : " + r['serial_number'])
                r['push_av'] = False
            else:
                log("Panorama and VM DO NOT have same Anti-Virus: " + av_version + " : " + iid + " : " + r['serial_number'])

            if d_candidate['app-version'] == content_version:
                log("Panorama and VM have same Apps and Threats: " + content_version + " : " + iid + " : " + r['serial_number'])
                r['push_app'] = False
            else:
                log("Panorama and VM DO NOT have same Apps and Threats: " + content_version + " : " + iid + " : " + r['serial_number'])

            if d_candidate['shared-policy-status'] == "In Sync":
                log("Panorama and VM Device Group are in sync: " + dg + " : " + iid + " : " + r['serial_number'])
                r['push_dg'] = False
            else:
                log("Panorama and VM Device Group are NOT in sync: " + dg + " : " + iid + " : " + r['serial_number'])

            return r
        else:
            log("FAILED: check_dg: Did not find " + iid + " on " + p + " in " + dg + ".  Should only happen on termination of instances that never failed to associate with Panorama")
            return r
    else:
        log("FAILED: check_dg: " + iid + " on " + p + ":" + dg + ": request")
        return r


def check_ts(p,key,iid,serial,ts):
    end = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    # Make sure VM Series TS is in sync with Panorama
    while not end:
            log("looking for instance_id:" + iid + " - serial:" + serial + " on " + p + ":" + ts + ". Must be connected to Panorama")
            url = "https://" + p + "/api/?type=op&cmd=<show><template-stack><name>" + ts + "</name></template-stack></show>"
            cmd = urllib.request.Request(url + "&key=" + key)
            urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
            response = urlcall.read()
            devices_ts_dict = xmltodict.parse(response)
            if devices_ts_dict['response']['@status'] == "success":
                d = devices_ts_dict['response']['result']['template-stack']['entry']['devices']['entry']
                # single device in TS on panorama - struct is dict
                if isinstance(d, dict):
                    if 'hostname' in d:
                        d_candidate = d
                # multiple devices in TS on panorama - struct changes is list of dict
                elif isinstance(d, list):
                    for device in d:
                        if 'hostname' in device and device['hostname'] == iid:
                            d_candidate = device
                if 'hostname' in d_candidate and d_candidate['hostname'] == iid and d_candidate['connected'] == "yes":
                    if d_candidate['template-status'] == "In Sync":
                        log("Panorama and VM Template Stack are in sync: " + ts + " : " + iid + " : " + serial)
                        return False
                    else:
                        log("Panorama and VM Template Stack are NOT in sync: " + ts + " : " + iid + " : " + serial)
                        return True
            time.sleep(30)

def push_dg_and_ts(p,key,serial,iid,dg):
    end = False
    job_id = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    while not end:
        url = "https://" + p  + "/api/?type=commit&action=all&cmd=<commit-all><shared-policy><include-template>yes</include-template><device-group><entry%20name=%22" + \
            dg + "%22><devices><entry%20name=%22" + serial + "%22/></devices></entry></device-group></shared-policy></commit-all>"
        cmd = urllib.request.Request(url + "&key=" + key)
        urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
        response = urlcall.read()
        commit_dict = xmltodict.parse(response)
        if commit_dict['response']['@status'] == "success":
            match_first = re.search(r'Job enqueued with jobid (\d+)$', commit_dict['response']['result']['msg']['line'])
            if match_first:
                job_id = match_first.group(1)
                log("Push DG and TS to " + serial + ": " + commit_dict['response']['result']['msg']['line'])
                end = True
        else:
            log("Failed to start commit job to VM Series: " + iid + " : " + dg)

        if not end:
            time.sleep(30)

    if (job_id):
        return check_panorama_job_status(p,key,job_id,serial)


def refresh_license_by_serial(p,key,serial):
    e = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    url = "https://" + p + "/api/?type=op&cmd=<request><batch><license><refresh><devices>" + serial + \
        "</devices></refresh></license></batch></request>"
    log("refresh_license_by_serial:" + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    refresh_dict = xmltodict.parse(response)
    log("refresh_license_by_serial:" + str(refresh_dict))
    job_id = False
    if refresh_dict['response']['@status'] == "success":
        match_first = re.search(r'Job enqueued with jobid (\d+)$', refresh_dict['response']['result']['msg']['line'])
        if match_first:
            job_id = match_first.group(1)
            log("SUCCESS: refresh_license_by_serial: submitted license refresh")
            return job_id
        else:
            log("FAIL: refresh_license_by_serial: could not find job id")
            return False
    else:
            log("FAIL: refresh_license_by_serial: submit license refresh")
    if job_id:
# Intermittent stuck jobs do wait for license refresh to complete lifecycle hook
# Only needed to CDL cert fixup 
#       return check_panorama_job_status(p,key,job_id,serial)
        return job_id

def push_content(p,key,serial,content_version):
    end = False
    job_id = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    while not end:
        url = "https://" + p + "/api/?type=op&cmd=<request><batch><content><upload-install><devices>" + serial + "</devices><file>panupv2-all-contents-" + content_version + "</file></upload-install></content></batch></request>"
        cmd = urllib.request.Request(url + "&key=" + key)
        urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
        response = urlcall.read()
        app_install_dict = xmltodict.parse(response)
        if app_install_dict['response']['@status'] == "success":
            match_first = re.search(r'Job enqueued with jobid (\d+)$', app_install_dict['response']['result']['msg']['line'])
            if match_first:
                job_id = match_first.group(1)
                log("Updating Apps and Threats Content on " + serial + ": " + app_install_dict['response']['result']['msg']['line'])
                end = True
        else:
            log("Failed to start content upload and install")

        if not end:
            time.sleep(30)

    if (job_id):
        return check_panorama_job_status(p,key,job_id,serial)

def push_antivirus(p,key,serial,av_version):
    end = False
    job_id = False
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    while not end:
        url = "https://" + p + "/api/?type=op&cmd=<request><batch><anti-virus><upload-install><devices>" + serial + "</devices><file>panup-all-antivirus-" + av_version+ "</file></upload-install></anti-virus></batch></request>"
        cmd = urllib.request.Request(url + "&key=" + key)
        urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
        response = urlcall.read()
        av_install_dict = xmltodict.parse(response)
        if av_install_dict['response']['@status'] == "success":
            match_first = re.search(r'Job enqueued with jobid (\d+)$', av_install_dict['response']['result']['msg']['line'])
            if match_first:
                job_id = match_first.group(1)
                log("Updating Anti-Virus Content on " + serial + ": " + av_install_dict['response']['result']['msg']['line'])
                end = True
        else:
            log("Failed to start content upload and install")
        if not end:
            time.sleep(30)

    if (job_id):
        return check_panorama_job_status(p,key,job_id,serial)

def delete_device_from_panorama(pano,key,serial,dg,ts):
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    url = "https://" + pano + "/api/?type=config&action=delete&xpath=" + \
        "/config/devices/entry[@name='localhost.localdomain']/template-stack/entry[@name='" + \
        ts + "']/devices/entry[@name='" + \
        serial + "']"
    log("delete_device_from_panorama: delete_ts:" + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    delete_ts_dict = xmltodict.parse(response)
    if delete_ts_dict['response']['@status'] == "success":
        log("SUCCESS: delete_device_from_panorama: delete_ts: " + str(delete_ts_dict))
    else:
        log("FAIL: delete_device_from_panorama: delete_ts: " + str(delete_ts_dict))
        return False

    url = "https://" + pano + "/api/?type=config&action=delete&xpath=" + \
        "/config/devices/entry[@name='localhost.localdomain']/device-group/entry[@name='" + \
        dg + "']/devices/entry[@name='" + \
        serial + "']"
    log("delete_device_from_panorama: delete_dg:" + url)
    cmd = urllib.request.Request(url + "&key=" + key) 
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    delete_dg_dict = xmltodict.parse(response)
    if delete_dg_dict['response']['@status'] == "success":
        log("SUCCESS: delete_device_from_panorama: delete_dg " + str(delete_dg_dict))
    else:
        log("FAIL: delete_device_from_panorama: delete_dg: " + str(delete_dg_dict))
        return False

    url = "https://" + pano + "/api/?type=config&action=delete&xpath=" + \
        "/config/mgt-config/devices/entry[@name='" + serial + "']"
    log("delete_device_from_panorama: delete_dev:" + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    delete_dev_dict = xmltodict.parse(response)
    if delete_dev_dict['response']['@status'] == "success":
        log("SUCCESS: delete_device_from_panorama: delete_dev: " + str(delete_dev_dict))
    else:
        log("FAIL: delete_device_from_panorama: delete_dev: " + str(delete_dev_dict))
        return False

    url = "https://" + pano + "/api/?type=commit&&cmd=<commit></commit>"
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    commit_dict = xmltodict.parse(response)
    if commit_dict['response']['@status'] == "success":
        match_first = re.search(r'enqueued with jobid (\d+)', commit_dict['response']['result']['msg']['line'])
        if match_first:
            job_id = match_first.group(1)
            if job_id:
                log("delete_device_from_panorama: Commit " + serial + ": " + commit_dict['response']['result']['msg']['line'])
                log("SUCCESS: delete_device_from_panorama: commit job:" + job_id + ": " + str(commit_dict))
                return check_panorama_job_status(pano,key,job_id,"")              
    else:
        log("FAIL: delete_device_from_panorama: commit job: " + str(commit_dict))
        return False

def add_serial_to_panorama(pano,key,serial):
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    url = "https://" + pano + "/api/?type=config&action=set&xpath=/config/mgt-config/devices&element=<entry%20name='" + serial + "'/>"
    log("add_device: " + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    add_serial_dict = xmltodict.parse(response)
    if add_serial_dict['response']['@status'] == "success":
        log("SUCCESS: add_device: " + str(add_serial_dict))
        return True
    else:
        log("FAIL: add_device: " + str(add_serial_dict))
        return False

def deactivate_serial(pano,key,serial):
    request_ctx = ssl.create_default_context()
    request_ctx.check_hostname = False
    request_ctx.verify_mode = ssl.CERT_NONE
    url = "https://" + pano + "/api/?type=op&cmd=<request><batch><license><deactivate><VM-Capacity><mode>auto</mode><devices>" + \
        serial + \
        "</devices></VM-Capacity></deactivate></license></batch></request>"
    log("deactivate_serial: " + url)
    cmd = urllib.request.Request(url + "&key=" + key)
    urlcall = urllib.request.urlopen(cmd, data=None, context=request_ctx, timeout=5)
    response = urlcall.read()
    deactivate_serial_dict = xmltodict.parse(response)
    if deactivate_serial_dict['response']['@status'] == "success":
        log("SUCCESS: deactivate_serial: " + str(deactivate_serial_dict))
        return True
    else:
        log("FAIL: deactivate_serial: " + str(deactivate_serial_dict))
        return False

def tag_instance(iid,k,v):
    try:
        ec2_client = boto3.client('ec2')
        response = ec2_client.create_tags(Resources=[iid,], Tags=[{'Key':k, 'Value':v}])
        log(str(response))

    except botocore.exceptions.ClientError as err:
        log("Boto ClientError: " + err.response['Error']['Code'])
def cold_launch(e,iid,p1,p2,p_api_key,dg,ts):
# Cold Launch will take a long time.  
# Lambda Functions timeout after 15 minutes.
# Lambda functions will retry 2 times.  45 minutes total runtime.
# Logic supports retries (3 separate invocations with no intermediate saved state). 
# Could just sleep long. But monitoring progress is interesting.
# Typically 25 minutes.

    log_group = 'PaloAltoNetworksFirewalls'
    logs_client = boto3.client('logs')
    i = 0
    lastlogseen = 0
    license_complete = False
    log("cold_launch: " + iid + ": " + str(i) + ": " + json.dumps(e))
    while (True):
        i+=1
        # Need Fail if - should add these
            # ERROR : LICENSE : FAIL :
            # ERROR : LICENSE : FAIL : License Install - Failed - Failed to install license key using authcode D12341234: Deployment profile input does not have enough credits available to support this request..
            # CRITICAL : COMMIT : FAIL : \d+ : Auto-commit job failed.
        try:
            response = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=iid,
                startTime=lastlogseen
            )
            # Tested with PAN-OS 10.1.5-h1
            for cw_event in response["events"]:
                log("Iterating over Cloud Watch Events:" + str(i) + ": " + cw_event["message"])
                if "INFO : LICENSE : COMPLETE : Firewall license" in cw_event["message"]:
                    license_complete = True
                    log("VM Series licensed: " + cw_event["message"])
                elif "Commit-all successful" in cw_event["message"] or \
                    ("Auto-commit job failed" in cw_event["message"] and \
                    "CRITICAL : COMMIT : FAIL" in cw_event["message"] and license_complete):
                    log("VM Series Commit-all from Panorama done enough to move forward: " + cw_event["message"])
                    check_panorama_dict = check_panorama(p1,p2,p_api_key)
                    panorama = check_panorama_dict['panorama']
                    panorama_app_version = check_panorama_dict['panorama_app_version']
                    panorama_av_version = check_panorama_dict['panorama_av_version']
                    if panorama != "":
                        check_dg_dict = check_dg(panorama,p_api_key,iid,dg,panorama_app_version,panorama_av_version)
                        serial_number = check_dg_dict['serial_number']
                        push_dg = check_dg_dict['push_dg']
                        push_app = check_dg_dict['push_app']
                        push_av = check_dg_dict['push_av']

                        if serial_number != "":
                            log("tag_instance: instance: serial")
                            tag_instance(iid,'serial',serial_number)
                            log("tag_instance: instance: license")
                            if is_byol_instance:
                                tag_instance(iid,'license','byol')
                            else:
                                tag_instance(iid,'license','payg')
                            log("Calling refresh_license_by_serial")
                            if refresh_license_by_serial(panorama,p_api_key,serial_number):
                                log("SUCCESS: refresh_license_by_serial for serial = " + serial_number)
                            else:
                                log("FAIL: refresh_license_by_serial for serial = " + serial_number)
                        else:
                            log("FAIL: no serial from check_dg for instance = " + iid)
                            return False

                        push_ts = check_ts(panorama,p_api_key,iid,serial_number,ts)

                        if push_av:
                            log("cold_launch: calling push_av")
                            push_antivirus(panorama,p_api_key,serial_number,panorama_av_version)

                        if push_app:
                            log("cold_launch: calling push_app")
                            push_content(panorama,p_api_key,serial_number,panorama_app_version)

                        if push_dg or push_ts:
                            log("cold_launch: push_dg_and_ts")
                            return push_dg_and_ts(panorama,p_api_key,serial_number,iid,dg)
                    else:
                        log("cold_launch: FAIL: Unable to calling check_dg: No active Panorama found from check_panorama")
                log("cold_launch: Found logs for Instance in CloudWatch, but no Commit-all post license: sleeping")
            # [ERROR] IndexError: list index out of range
            """
            Traceback (most recent call last):
  File "/var/task/warmasglambda.py", line 774, in lambda_handler
    if cold_launch(event,instance_id,panorama_pri,panorama_sec,panorama_api_key,device_group,template_stack):
  File "/var/task/warmasglambda.py", line 496, in cold_launch
    lastlogseen = response["events"][-1]["timestamp"]
[ERROR] IndexError: list index out of range Traceback (most recent call last):   File "/var/task/warmasglambda.py", line 774, in lambda_handler     if cold_launch(event,instance_id,panorama_pri,panorama_sec,panorama_api_key,device_group,template_stack):   File "/var/task/warmasglambda.py", line 496, in cold_launch     lastlogseen = response["events"][-1]["timestamp"]
            """
            #lastlogseen = response["events"][-1]["timestamp"]
            time.sleep(30)

        except botocore.exceptions.ClientError as err: 
            log("cold_launch: " + iid + ": cloudwatch get_log_events - ERROR: " + err.response['Error']['Code'])
            time.sleep(30)

def is_byol_instance(iid):
    ec2_client = boto3.resource('ec2')
    instance = ec2_client.Instance(iid)
    if len(instance.product_codes) > 0 and \
        instance.product_codes[0] != None and \
        instance.product_codes[0]['ProductCodeId'] != None  and \
        instance.product_codes[0]['ProductCodeId'] == "6njl1pau431dv1qxipg63mvah": 
        return True 
    else: 
        return False


def get_secret_value(name, version=None):
    try:
        client = boto3.client('secretsmanager')
        kwargs = {'SecretId': name}
        response = client.get_secret_value(**kwargs)
        return response
    except botocore.exceptions.ClientError as err:
        log("get_secret_value: ClientError: " + err.response['Error']['Code'])
        return False

def terminate(p1,p2,pk,iid,dg,ts,l):
    # Get Active Panorama IP
    check_panorama_dict = check_panorama(p1,p2,pk)
    panorama_app_version = check_panorama_dict['panorama_app_version']
    panorama_av_version = check_panorama_dict['panorama_av_version']
    panorama = check_panorama_dict['panorama']

    # Get Serial number from EC2 Instance ID
    check_dg_dict = check_dg(panorama,pk,iid,dg,panorama_app_version,panorama_av_version)
    serial_number = check_dg_dict['serial_number']
    if serial_number != "":
        # Check EC2 Instance Product Code on AMI for BYOL
        # Delicense if BYOL
        if l == "byol":
            # This will catch instances that are terminated by ASG.  (Cannot check product codes on instance that is fully terminated)
            log("terminate: deactivate_serial " + serial_number)
            deactivate_serial(panorama,pk,serial_number)

        if delete_device_from_panorama(panorama,pk,serial_number,dg,ts):
            log("SUCCESS: deleted instance_id from Panorama: panorama: device_group: template_stack")
            return True
        else:
            # revert panorama - Need to Implement
            log("FAIL: failed to delete instance_id from Panorama: panorama: device_group: template_stack")
            return False
    else:
        log("TERMINATING: ERROR: no serial number on Panorama " + panorama + " for " + iid)
        return False
        # lookup tag on instance and call delete_device_from_panorama.
        # this will cleanup manual deletes from panorama
        # this will not cleanup partial launches that are terminated before association with panorama

def warm_launch(p1,p2,pk,iid,dg,ts):
    check_panorama_dict = check_panorama(p1,p2,pk)
    panorama_app_version = check_panorama_dict['panorama_app_version']
    panorama_av_version = check_panorama_dict['panorama_av_version']
    panorama = check_panorama_dict['panorama']

    check_dg_dict = check_dg(panorama,pk,iid,dg,panorama_app_version,panorama_av_version)

    serial_number = check_dg_dict['serial_number']
    push_dg = check_dg_dict['push_dg']
    push_app = check_dg_dict['push_app']
    push_av = check_dg_dict['push_av']

    push_ts = check_ts(panorama,pk,iid,serial_number,ts)

    if push_av:
        log("push_antivirus: calling")
        if push_antivirus(panorama,pk,serial_number,panorama_av_version):
            log("push_antivirus: success")
        else:
            log("push_antivirus: failed abandon" )
            return False

    if push_app:
        log("push app: calling")
        if push_content(panorama,pk,serial_number,panorama_app_version):
            log("push_content: success")
        else:
            log("push_content: failed abandon" )
            return False


    if push_dg or push_ts:
        log("push_dg_and_ts: calling")
        if push_dg_and_ts(panorama,pk,serial_number,iid,dg):
            log("push_dg_and_ts: success")
        else:
            log("push_dg_and_ts: failed abandon" )
            return False

    refresh_license_by_serial(panorama,pk,serial_number)

    # Panorama should have instance, but not connected.  Wait for connection and push content, TS and DG.
    log("complete lifecycle hook for Warm Pool Launch to AutoScalingGroup")
    return True

def create_interface(subnet_id,security_group_id,description):
    network_interface_id = None

    if subnet_id:
        try:
            ec2_client = boto3.client('ec2')
            network_interface = ec2_client.create_network_interface(Description=description,SubnetId=subnet_id,Groups=[security_group_id])
            network_interface_id = network_interface['NetworkInterface']['NetworkInterfaceId']
            log("Created network interface: {}".format(network_interface_id))
        except botocore.exceptions.ClientError as e:
            log("Error creating network interface: {}".format(e.response['Error']['Code']))

    return network_interface_id

""""
def attach_interface(network_interface_id, instance_id,device_index):
    attachment = None

    if network_interface_id and instance_id:
        log("attach_interface: network_interface_id: {}".format(network_interface_id))
        log("attach_interface: instance_id: {}".format(instance_id))
        try:
            ec2_client = boto3.client('ec2')
            attach_interface = ec2_client.attach_network_interface(
                NetworkInterfaceId=network_interface_id,
                InstanceId=instance_id,
                DeviceIndex=device_index
            )
            attachment = attach_interface['AttachmentId']
            log("Created network attachment: {}".format(attachment))
        except botocore.exceptions.ClientError as e:
            log("Error attaching network interface: {}".format(e.response['Error']['Code']))

    return attachment
"""

def delete_interface(network_interface_id):
    try:
        ec2_client = boto3.client('ec2')
        ec2_client.delete_network_interface(
            NetworkInterfaceId=network_interface_id
        )
        return True
    except botocore.exceptions.ClientError as e:
        log("Error deleting interface {}: {}".format(network_interface_id, e.response['Error']['Code']))

def get_unassigned_public_ips():
    ec2_client = boto3.client('ec2')
    response = ec2_client.describe_addresses()
    unassigned_public_ips = []
    for a in response['Addresses']:
        if 'AssociationId' not in a: 
            unassigned_public_ips.append(a['AllocationId'])
    return unassigned_public_ips

def get_instance_az(instance_id):
    try:
        ec2_client = boto3.client('ec2')
        result = ec2_client.describe_instances(InstanceIds=[instance_id])
        az = result['Reservations'][0]['Instances'][0]['Placement']['AvailabilityZone']
    except botocore.exceptions.ClientError as e:
        log("get_instance_az: ERROR describing the instance {}: {}".format(instance_id, e.response['Error']['Code']))

    return az

def get_available_nics_with_eip(sn,sg):
    client = boto3.client('ec2')
    response = client.describe_network_interfaces(
        Filters=[
            {
                    'Name': 'status',
                    'Values': ['available',]
            },
            {
                    'Name': 'association.public-ip',
                    'Values': ['*',]

            },
            { 
                    'Name': 'group-id',
                    'Values': [sg,]
            },
            {
                    'Name': 'subnet-id',
                    'Values': [sn,]
            }
        ]
        )
    eni_id = ""
    for eni in response['NetworkInterfaces']:
        eni_id = eni['NetworkInterfaceId']
    return eni_id

def get_available_nics(sn,sg):
    client = boto3.client('ec2')
    response = client.describe_network_interfaces(
        Filters=[
            {
                    'Name': 'status',
                    'Values': ['available',]
            },
            { 
                    'Name': 'group-id',
                    'Values': [sg,]
            },
            {
                    'Name': 'subnet-id',
                    'Values': [sn,]
            }
        ]
        )
    eni_id = ""
    for eni in response['NetworkInterfaces']:
        eni_id = eni['NetworkInterfaceId']
    return eni_id

def add_nic(e):
    instance_id = e["detail"]["EC2InstanceId"]
    extra_nic_subnet_id = None
    extra_nic_security_group_id = None
    ec2_client = boto3.client('ec2')
    az = get_instance_az(instance_id)
    if e["detail"]["NotificationMetadata"]["extra_nic_subnets"]!= None:
        if e["detail"]["NotificationMetadata"]["extra_nic_subnets"][az] != None and \
            e["detail"]["NotificationMetadata"]["extra_nic_sg"] != None:
            instance_id = e['detail']['EC2InstanceId']
            extra_nic_subnet_id = e["detail"]["NotificationMetadata"]["extra_nic_subnets"][az]
            extra_nic_security_group_id = e["detail"]["NotificationMetadata"]["extra_nic_sg"]
            log("extra_nic_subnet_id = " + extra_nic_subnet_id)
            log("extra_nic_security_group_id = " + extra_nic_security_group_id)

            i=0
            while True:
                di_resp = ec2_client.describe_instances(InstanceIds=[instance_id])
                if len(di_resp['Reservations'][0]['Instances'][0]['NetworkInterfaces']) == 3:
                    log("add_nic: " + instance_id + " has 3 NICs. done here")
                    return True

                interface_id = get_available_nics_with_eip(extra_nic_subnet_id,extra_nic_security_group_id)
                if interface_id == "":
                    interface_id = get_available_nics(extra_nic_subnet_id,extra_nic_security_group_id)
                    if interface_id == "":
                        eni_description = "en2"
                        interface_id = create_interface(extra_nic_subnet_id,extra_nic_security_group_id,eni_description)
                        log("add_nic: created interface_id: {}".format(interface_id))
                    eips = get_unassigned_public_ips()
                    log("add_nic: eips:" + str(type(eips)) + " len: " + str(len(eips)) + " str: " + str(eips))
                    if len(eips) == 0:
                        time.sleep(i*30)
                        try:
                            allocation = ec2_client.allocate_address(Domain='vpc')
                        except botocore.exceptions.ClientError as err:
                            log("add_nic: allocate_address: ClientError: " + err.response['Error']['Code'])
                        else:
                            if allocation['AllocationId'] != None:
                                log("add_nic: allocate_address: SUCCESS: " + allocation['AllocationId'])
                                eips.append(allocation['AllocationId'])
                            else:
                                log("add_nic: allocate_address: FAIL")
                                return False

                    for eip in eips:
                        log("add_nic: associate_address starting")
                        try:
                            association = ec2_client.associate_address(
                                AllocationId=eip,
                                NetworkInterfaceId=interface_id,
                                AllowReassociation=False
                            )
                        except botocore.exceptions.ClientError as err:
                            log("add_nic: associate_address: FAIL: ClientError: " + err.response['Error']['Code'])
                            continue
                        else:
                            log("add_nic: associate_address: SUCCESS {}".format(association))

                        log("add_nic: attach_network_interface starting: " + instance_id + ": " + interface_id)
                        try:
                            device_index = 2
                            ec2_client = boto3.client('ec2')
                            attach_interface = ec2_client.attach_network_interface(
                                NetworkInterfaceId=interface_id,
                                InstanceId=instance_id,
                                DeviceIndex=device_index
                            )
                            attachment = attach_interface['AttachmentId']
                            log("Created network attachment: {}".format(attachment))
                        except botocore.exceptions.ClientError as e:
                            log("add_nic: attach_network_interface: FAIL {}".format(e.response['Error']['Code']))
                            return False
                        else:
                            log("add_nic: attach_network_interface: SUCCESS {}".format(attachment))

                        log("add_nic: modify_network_interface_attribute: starting")
                        try:
                            delete = ec2_client.modify_network_interface_attribute(
                                Attachment={
                                    'AttachmentId': attachment,
                                    'DeleteOnTermination': True,
                                    },
                                    NetworkInterfaceId = interface_id,
                                )
                        except botocore.exceptions.ClientError as err:
                            log("add_nic: modify_network_interface_attribute: ClientError: " + err.response['Error']['Code'])
                            return False
                        else:
                            log("add_nic: modify_network_interface_attribute: {}".format(delete))
                            break
                else:
                    log("add_nic: attach_network_interface - existing ENI with EIP: " + instance_id + ": " + interface_id)
                    try:
                        device_index = 2
                        ec2_client = boto3.client('ec2')
                        attach_interface = ec2_client.attach_network_interface(
                            NetworkInterfaceId=interface_id,
                            InstanceId=instance_id,
                            DeviceIndex=device_index
                        )
                        attachment = attach_interface['AttachmentId']

                    except botocore.exceptions.ClientError as e:
                        log("add_nic: attach_network_interface: Existing ENI with EIP: FAIL: {}".format(e.response['Error']['Code']))
                        return False
                    else:
                        log("add_nic: attach_network_interface: Existing ENI with EIP: SUCCESS: {}".format(attachment))
                i += 1
        else:
            log("No Subnet ID found in Lifecycle Metadata in " + az + " for " + instance_id)
            return False
    else:
        log("No Extra NICs in metadata: will not add additional data plane ENIs")
        return False

def complete_lifecycle(event,result,instance_id):
    asg_client = boto3.client('autoscaling')
    try:
        log("Completing Lifecycle for " + instance_id + json.dumps(event))
        asg_client.complete_lifecycle_action(
            LifecycleHookName=event['detail']['LifecycleHookName'],
            AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
            LifecycleActionToken=event['detail']['LifecycleActionToken'],
            LifecycleActionResult=result
            )
    except botocore.exceptions.ClientError as e:
        log("Error completing life cycle hook for instance {}: {}".format(event['detail']['EC2InstanceId'], e.response['Error']['Code']))

def lambda_handler(event, context):
    log("lambda_handler: " + json.dumps(event))
    lifecycle_result="CONTINUE"
    user_data_secret = get_secret_value(event['detail']['NotificationMetadata']['secret_user_data'])

    if user_data_secret == False:
        lifecycle_result ="ABANDON"
        complete_lifecycle(event,lifecycle_result,instance_id)

    user_data_secret_json = json.loads(user_data_secret['SecretString'])
    panorama_pri = user_data_secret_json['panorama-server']
    panorama_sec = user_data_secret_json['panorama-server-2']
    device_group = user_data_secret_json['dgname']
    template_stack = user_data_secret_json['tplname']
    panorama_secret = get_secret_value(event['detail']['NotificationMetadata']['secret_panorama'])

    if panorama_secret == False:
        lifecycle_result ="ABANDON"
        complete_lifecycle(event,lifecycle_result,instance_id)

    panorama_secret_json = json.loads(panorama_secret['SecretString'])
    panorama_api_key = panorama_secret_json['panorama_api_key']
    instance_id = event['detail']['EC2InstanceId']

    if event['detail']['LifecycleTransition'] == 'autoscaling:EC2_INSTANCE_LAUNCHING' and event['detail']['Origin'] == 'EC2':
        # Launch from EC2
        if event["detail"]["NotificationMetadata"]["extra_nic_subnets"] != None:
            log("calling: add_nic")
            if add_nic(event):
                log("add_nic: SUCCESS")
                pass
            else:
                log("add_nic: FAILURE")
                lifecycle_result = "ABANDON"
                complete_lifecycle(event,lifecycle_result,instance_id)
                return
        else: 
            log("skipping: add_nic: no additional data-plane ENI")

        log("cold_launch: calling")
        if cold_launch(event,instance_id,panorama_pri,panorama_sec,panorama_api_key,device_group,template_stack):
            log("cold_launch: SUCCESS")
        else:
            log("cold_launch: FAILURE - Lifecycle ABANDON")
            lifecycle_result = "ABANDON"
    elif event['detail']['LifecycleTransition'] == 'autoscaling:EC2_INSTANCE_TERMINATING' and event['detail']['Destination'] == 'EC2':
            # Full Instance Termination - No Reuse
            if 'license' in event['detail']['NotificationMetadata']:
                license = event['detail']['NotificationMetadata']['license']
            else:
                license = "byol"
            log("Remove from Panorama and if PayGo Delicense VM Flex License for {}".format(instance_id))
            if terminate(panorama_pri,panorama_sec,panorama_api_key,instance_id,device_group,template_stack,license):
                log("terminate: SUCCESS")
            else:
                log("termiante: FAILURE - Lifecycle ABANDON")
                lifecycle_result = "ABANDON"
    elif event['detail']['LifecycleTransition'] == 'autoscaling:EC2_INSTANCE_TERMINATING' and event['detail']['Destination'] == 'WarmPool':
            # Only get here is Warm Pool is configured for Instance reuse
            log("Scaling In with Reuse.  Do not delicense {}".format(instance_id))
            # Fall through to lifecycle complete
            pass
    elif event['detail']['LifecycleTransition'] == 'autoscaling:EC2_INSTANCE_LAUNCHING' and event['detail']['Origin'] == 'WarmPool':
            # Launch from Warm Pool to ASG
            log("warm_launch: starting")
            log("Scaling Out from warm pool to AutoScaling Group. Push content, TS, and DG for {}".format(instance_id))
            if warm_launch(panorama_pri,panorama_sec,panorama_api_key,\
                instance_id,device_group,template_stack):
                log("warm_launch: SUCCESS")
            else:
                log("warm_launch: FAILURE - Lifecycle ABANDON")
                lifecycle_result = "ABANDON"
    else:
        log("UNKNOWN Lifecycle")
        lifecycle_result = "ABANDON"

    complete_lifecycle(event,lifecycle_result,instance_id)
    return
