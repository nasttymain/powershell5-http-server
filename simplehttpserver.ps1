function _get_files_list {
	param ()
	Set-Variable -Name "flist" -Value ((Get-ChildItem -Path root/ -name -recurse -file).replace("\", "/")) -Scope "Script"
	
}

$flist = ""
_get_files_list

$tcplistener = New-Object System.Net.Sockets.TcpListener(80)
$tcplistener.Stop()
$tcplistener.Start()
$tcplistener.Pending()

try {
	while($True){
		if($tcplistener.Pending() -eq $True){
			$c = $tcplistener.AcceptTcpClient()
			$s = $c.GetStream()
			$rx_bin = New-Object System.Byte[] 65536
			[void] $s.Read($rx_bin, 0, 65536)

			$rlcnt = -1
			$method = ""
			$resource = ""
			$resource_src = ""
			$end_request = $False
			# 空行に到達するまで繰り返す
			while($end_request -eq $False){
				foreach ($rl in ([System.Text.Encoding]::UTF8.GetString($rx_bin) -split "`n").Trim("`n").Trim("`r") ){
					$rlcnt += 1
					if($rlcnt -eq 0){
					[String] $method = ($rl -split " ")[0]
					[String] $resource = ($rl -split " ")[1]
					[String] $resource_src = ($rl -split " ")[1]
					}
					if ($rl -eq ""){
						$end_request = $True
					}
				}
			}

			if ($resource.EndsWith("/")){
				# パスが / で終わる場合は index.html
				$resource += "index.html"
			}elseif ($resource.StartsWith("/") -ne $True) {
				# パスが / で始まらない場合は、先頭に / を追加する
				$resource = "/" + $resource
			}

			# パス先頭の / を削除する
			$resource = $resource.Substring(1)


			if ($method -eq "GET"){
				$ffound = ($flist | Where-Object {$_ -eq $resource})
				if ($null -ne $ffound -and $True -eq ([System.IO.File]::Exists("root/" + $ffound)) ){
					$status = 200
					$tx_bin = [System.Text.Encoding]::UTF8.GetBytes( "HTTP/1.0 200 OK`n`n" + (Get-Content ("root/" + $ffound)) )
				}else{
					_get_files_list
					$ffound = ($flist | Where-Object {$_ -eq $resource})
					if ($null -ne $ffound){
						$status = 200
						$tx_bin = [System.Text.Encoding]::UTF8.GetBytes( "HTTP/1.0 200 OK`n`n" + (Get-Content ("root/" + $ffound)) )
					}else{
						$status = 404
						$tx_bin = [System.Text.Encoding]::UTF8.GetBytes("HTTP/1.0 404 Not Found`n`n404 Not Found`n")
					}
				}
			}else{
				$status = 405
				$tx_bin = [System.Text.Encoding]::UTF8.GetBytes("HTTP/1.0 405 Method Not Allowed`n`nMethod Not Allowed`n")
			}
			
			
			$s.Write($tx_bin, 0, $tx_bin.Length);
			$s.Close()

			Write-Output ([String]($status) + " " + $method + " " + $resource_src + " " + $resource)

			$s.Dispose()
			$c.Close()
			$c.Dispose()
		}else{
			Start-Sleep -Milliseconds 100
		}
	}
}finally {
	$tcplistener.Stop()
}
