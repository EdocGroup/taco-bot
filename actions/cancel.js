"use strict";

var cancelUpdateServerAction = {
    command: '!Cancel',
    helpDisplayCommand: '!Cancel // ths must be used immediately after !Update-Server',
    description: 'Stops install-releasecandidate.ps1 from continuing its deploy.',
    perform: function (options) {
    	
                var output = [   "Killing powershell.exe on ED-BLDSEL07" ];										
				var child = require('child_process').exec("cmd.exe /c taskkill.exe /IM powershell.exe /F");
				child.stdout.pipe(process.stdout);

       return '```' + output + '```';

	}
};


module.exports = cancelUpdateServerAction;

