"use strict";

var updateServerAction = {
    command: '!Update-Server:',
    helpDisplayCommand: '!Update-Server:<server>:<fullrevision>',
    description: 'Utilizes install-releasecandidate.ps1 to update an internal server with a revision of RC. If you want to wipe the DB add .YES to the revision',
    perform: function (options) {
    	
                   var invoke = options.message.text.split(updateServerAction.command)[1].split(" ")[0].trim(); 
				   var server = invoke.split(":")[0];
				   var revision = invoke.split(":")[1];
				   var output = [   "Updating Server",
									"Server: " + server, 
									"With Revision: " + revision,
									"If you want to stop this process... (quickly type !Cancel)"
								];										
			var result = executeUpdateScript(server,revision);				               	

       return '```' + output[0] + '\n' + output[1] + '\n' + output[2] + '\n' + output[3] + '\n' + '```' + '\n' + '```' + 'executing command' + '\n' + result + '```';


//return '```' + output.join('') + '```';
	}
};


 function executeUpdateScript(server, revision) {


 console.log("entering executeUpdateScript function");

 var major = revision.split('.')[0];
 var minor = revision.split('.')[1];
 var build = revision.split('.')[2];
 var rev = revision.split('.')[3];
 var wipe = revision.split('.')[4];

  var output = [
        "Server: " + server,
        "Revision: " + revision,
        "Major: " + major,		
		"Minor: " + minor,		
		"Build: " + build,		
		"Rev: " + rev,		

    ];	
	
var result = ("powershell.exe -ExecutionPolicy unrestricted -Command \" & 'tools\\Install-ReleaseCandidate.ps1' -Server '" + server + "' -Major '" + major + "' -Minor '" + minor +  "' -Build '" + build + "' -Revision '" + rev + "' -Wipe '" + wipe + "'\" " );
var child = require('child_process').exec("powershell.exe -ExecutionPolicy unrestricted -Command \" & 'tools\\Install-ReleaseCandidate.ps1' -Server '" + server + "' -Revision '" + rev + "' -Build '" + build + "' -Major '" + major + "' -Minor '" + minor + "' -Wipe '" + wipe + "'\" " );
child.stdout.pipe(process.stdout);

console.log(output);

console.log("exiting executeUpdateScript function");

return result;
}
module.exports = updateServerAction;

//!Update-Server:RC:7.0.12.83