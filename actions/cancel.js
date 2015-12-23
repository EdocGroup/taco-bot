"use strict";

var cancelUpdateServerAction = {
    command: '!Cancel',
    description: 'Stops install-releasecandidate.ps1 from continuing its deploy.',
    perform: function (options) {
    	
                var output = [  "Killing powershell.exe on host machine." ];										
				var child = require('child_process').exec("cmd.exe /c taskkill.exe /IM powershell.exe /F");
				child.stdout.pipe(process.stdout);

       //return '```' + output + '```';

	}
};


module.exports = cancelUpdateServerAction;

