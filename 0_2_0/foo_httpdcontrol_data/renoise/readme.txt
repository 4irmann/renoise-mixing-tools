Renoise foo_httpcontrol template
1.0 Jan 2012 http://code.google.com/p/airmann-mixing-tools/

*** Requirements

	This simplistic template is developed to be running together with
  the Renoise web client 
	 
	foobar2000 1.0 and foo_httpcontrol 0.97.7 or more recent versions
	are required.

*** Installation

	Extract archive contents retaining directory structure
	to %APPDATA%\foobar2000\foo_httpcontrol_data\renoise\ if foobar200 is installed
	in standard mode, or to path_too_foobar2000_folder\foo_httpcontrol_data\renoise\
	if foobar2000 is installed in portable mode.

*** Usage

	Open http://127.0.0.1:8888/default/ in your browser / Renoise client
	(Note that IP address and port is component configuration specific 
	and may be different in your case).

	It is recommended to enable "Cursor follows playback" option in 
	foobar2000 Playback menu for more convenient playlists browsing.

	You are free to change template parameters by editing default/config
	file. For example, playlist_items_per_page variable is useful when you
	want to modify playlist page size.

*** Release history 

	1/2012
		branched from default template
