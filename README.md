# Sign Message
Powershell script for recieving and displaying messages from a HTTP request, based on and configured for C2202-PD.

Assumes a sign with 2 rows and a length of 40 characters in total, character length can be easily changed however reconfiguring for more rows might take a bit more work.


Messages can be sent with Powershell using
```Invoke-WebRequest "http://localhost:26604/?Your Text Here"```

Linux curl doesn't support spaces like Powershell does so they must manually be replaced like
```curl http://localhost:26604/?$(echo "Your Text Here" | sed 's/ /%20/g')```

Note: This was before I knew the form feed special character (\`f) could be used to both clear the screen and reset the cursor and I'm lazy.
