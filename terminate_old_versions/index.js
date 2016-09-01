const spawn = require('child_process').spawn;

exports.handler = function(event, context) {
  const terminator = spawn('./terminator', ["-terminateOldVersions=true", "-port=8080", "-isDryRun=false"]);

  terminator.stdout.on('data', (data) => {
    console.log(`stdout: ${data}`);
  });

  terminator.stderr.on('data', (data) => {
    console.log(`stderr: ${data}`);
  });

  terminator.on('close', (code) => {
    console.log(`child process exited with code ${code}`);
    
    if(code !== 0) {
      return context.done(new Error("Process exited with non-zero status code"));
    }

    context.done(null);
  });
}