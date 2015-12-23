"use strict";

var updateServerAction = {
    command: '!Restart-Server:',
    helpDisplayCommand: '!Restart-Server:<server>:<YES_all_caps_to_wipe_db>:<alert>',
    description: 'Executes a powershell script to stop and start the service, and optionally wipe the associated DB. If you want to wipe the DB pass \"YES\" in all caps to the second param server name',
    perform: function (options) {
    	
                   var invoke = options.message.text.split(updateServerAction.command)[1].split(" ")[0].trim(); 
				   var server = invoke.split(":")[0];
				   var wipe = invoke.split(":")[1] || 0;
				   var alert = invoke.split(":")[2] || "Version";
				   var output = [   "Restarting Server",
									"Server: " + server, 
									"Wipe: " + wipe									
								];									

	
			var result = executeRestartScript(server, wipe, alert);				               	

       return '```' + output[0] + '\n' + output[1] + '\n' + output[2] + '\n' + '```' + '\n' + '```' + 'executing command' + '\n' + result + '```';

	}
};


 function executeRestartScript(server, wipe, alert) {


var result = ("powershell.exe -ExecutionPolicy unrestricted -Command \" & 'tools\\Restart-Server.ps1' -Server '" + server + "' -Wipe '" + wipe + "' -Alert '" + alert + "'\" " );

var child = require('child_process').exec("powershell.exe -ExecutionPolicy unrestricted -Command \" & 'tools\\Restart-Server.ps1' -Server '" + server + "' -Wipe '" + wipe + "' -Alert '" + alert + "'\" " );

child.stdout.pipe(process.stdout);

return result;
}
module.exports = updateServerAction;

