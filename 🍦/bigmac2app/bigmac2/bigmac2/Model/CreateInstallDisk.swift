//
//  CreateInstallDisk.swift
//  bigmac2
//
//  Created by starplayrx on 12/21/20.
//

import Foundation

extension ViewController {
    
    func downloadPkg() {
        //Remove pre-existing file
        _ = runCommandReturnString(binary: "/bin/rm", arguments: ["-Rf","/tmp/InstallAssistant.pkg"]) //Future check if it's complete and has right checksum
        
        DispatchQueue.global(qos: .background).async {
            self.download(urlString: "https://starplayrx.com/downloads/bigmac/BaseSystem_offline.dmg")
        }
    }
    
    //MARK: Install Shared Support DMG
    internal func installSharedSupportDMG() {
        DispatchQueue.global(qos: .background).async { [self] in
            copyFile(atPath: "/Applications/Install macOS Big Sur.app/Contents/SharedSupport/SharedSupport.dmg", toPath: "/Volumes/macOS Base System/SharedSupport.dmg")
        }
    }
    
    //MARK: Increment Install Fuel Gauge
    internal func incrementInstallGauge(resetGauge: Bool, incremment: Bool, setToFull: Bool) {
        
        DispatchQueue.main.async { [self] in
            
            if resetGauge {
                installerFuelGauge.doubleValue = installerFuelGauge.minValue
            }
            
            if incremment {
                installerFuelGauge.doubleValue += 1
            }
            
            if setToFull {
                installerFuelGauge.doubleValue = installerFuelGauge.maxValue
            }
        }
    }
    
    //MARK: Spinner Animation
    internal func spinnerAnimation (start: Bool, hide: Bool) {
        
        DispatchQueue.main.async { [self] in
            if start {
                createInstallSpinner.startAnimation(self)
            } else {
                createInstallSpinner.stopAnimation(self)
            }
            
            if hide {
                createInstallSpinner.isHidden = true
            } else {
                createInstallSpinner.isHidden = false
            }
        }
        
    }
    
    //MARK: Check for root user
    internal func checkForRootUser () -> Bool {
        rootMode || NSUserName() == "root" ? true : false
    }
    
    //MARK: Make Directory - To do use File Manager (For alot of these future tasks)
    internal func mkDir(bin: String = "/bin/mkdir", arg: String) -> String {
        let result = runCommandReturnString(binary: bin , arguments: [arg]) ?? ""
        return result
    }
    
    //MARK: Mount diskimage and parse disk#s#
    internal func mountDiskImage(bin: String = "/usr/bin/hdiutil", arg: [String]) -> String {
        
        if var mountedDisk = runCommandReturnString(binary: bin , arguments: arg) {
            
            for _ in 1...3 {
                mountedDisk = mountedDisk.replacingOccurrences(of: "     ", with: " ")
                mountedDisk = mountedDisk.replacingOccurrences(of: "   ", with: " ")
                mountedDisk = mountedDisk.replacingOccurrences(of: "  ", with: " ")
            }
            
            let hdiArray1 = mountedDisk.components(separatedBy: "\n")
            var hdiArray2 = [[String]]()
            for var i in hdiArray1 {
                i = i.replacingOccurrences(of: " ", with: "")
                
                var subArray = i.components(separatedBy: "\t")
                
                if let _ = subArray.last?.isEmpty {
                    subArray = subArray.dropLast()
                }
                
                if !subArray.isEmpty {
                    hdiArray2.append(subArray)
                }
            }
            return mountedDisk
        }
        return ""
    }
    
    //MARK: Extract DMG from Zip file
    func extractDMGfromZip(bin: String = "/usr/bin/unzip", arg: [String] ) -> String {
        let result = runCommandReturnString(binary: bin , arguments: arg) ?? ""
        return result
    }
    
    //MARK: Installer disk Root Mode Function (if not root mode, then uses NSAppleScript to make the call)
    func addVolume(binStr: String, argStr: String, dmgPath: String, targetDisk: String, erase: Bool) -> String {
        var eraseString = ""
      
        var args = ["--source", dmgPath, "--target", targetDisk, "-noverify", "-noprompt"]
        
        if erase {
            eraseString = "--erase"
            args.append(eraseString)
        }
        
        let result = runCommandReturnString(binary: "/usr/sbin/asr", arguments: ["\(argStr)"]) ?? ""
        return result
    }
    
    
    func eraseDisk(bin: String = "/usr/sbin/diskutil", diskSlice: String ) -> String {
        let result = runCommandReturnString(binary: bin, arguments: ["reformat", diskSlice]) ?? ""
        return result
    }
    
    
    //MARK: Install Disk Setup
    func disk(isBeta:Bool, diskInfo: myVolumeInfo) {
        
        let tmp = "tmp"
        let sharedsupport = "SharedSupport"
        let bigmac2 = "bigmac2"
        let tempDiskImage = "bm2tmp0"
        
        let applications = "Applications"
        let basesystem = "BaseSystem"
        let appFolder = Bundle.main.resourceURL
        let dmgPath = "\(appFolder!.path)/\(tempDiskImage).dmg"
        let macSoftwareUpdate = "com_apple_MobileAsset_MacSoftwareUpdate"
        var installBigSur = "Install macOS Big Sur.app"
        let wildZip = "*.zip"
        let restoreBaseSystem = "AssetData/Restore/\(basesystem).dmg"
        
        if isBeta {
            installBigSur = "Install macOS Big Sur Beta.app"
        }
        
        DispatchQueue.global(qos: .background).async { [self] in
            incrementInstallGauge(resetGauge: true, incremment: false, setToFull: false)
            spinnerAnimation(start: true, hide: false)
            
            //MARK: Erase disk inplace using reformat
            let resultEraseDisk = eraseDisk(diskSlice: diskInfo.diskSlice)
            print(resultEraseDisk)
            incrementInstallGauge(resetGauge: false, incremment: true, setToFull: false)
            
            //MARK: make temp dir SharedSupport
            let mkdir = mkDir(arg: "/\(tmp)/\(sharedsupport)")
            print(mkdir)
            
            //MARK: mount disk idmage inside temp SharedSupport
            let mountedDisk = mountDiskImage(arg: ["mount", "-mountPoint", "/\(tmp)/\(sharedsupport)", "/\(applications)/\(installBigSur)/Contents/\(sharedsupport)/\(sharedsupport).dmg", "-noverify", "-noautoopen", "-noautofsck", "-nobrowse"])
            print(mountedDisk)
            
            incrementInstallGauge(resetGauge: false, incremment: true, setToFull: false)
            
            let extract = extractDMGfromZip(arg: ["-o", "/\(tmp)/\(tmp)/\(macSoftwareUpdate)/*.\(wildZip)", "\(restoreBaseSystem)", "-d", "/\(tmp)"])
            print(extract)
            incrementInstallGauge(resetGauge: false, incremment: true, setToFull: false)
            
            
            //  let fm = FileManager.default
            
            //fm.replaceItemAt(<#T##originalItemURL: URL##URL#>, withItemAt: <#T##URL#>, backupItemName: <#T##String?#>, options: <#T##FileManager.ItemReplacementOptions#>)
            // let itemsToCopy = try! fm.contentsOfDirectory(atPath:  "/Volumes/macOS Base System")
            // print(itemsToCopy)
            
            //for i in itemsToCopy {
            // try? fm.copyItem(atPath: "/Volumes/macOS Base System/\(i)", toPath: "/Volumes/bigmac2/\(i)")
            
            // try? fm.copyItem(atPath: "/Volumes/macOS Base System/", toPath: "/Volumes/bigmac2/")
            
            
            
            incrementInstallGauge(resetGauge: false, incremment: true, setToFull: false)
            spinnerAnimation(start: false, hide: true)
            
        }
    }
    
}
