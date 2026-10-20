on dest(p)
	return POSIX file p
end dest
-- Usage: osascript saveatt.applescript <sender part> <folder> <Mail account name> <subject part>
on run argv
	set senderPart to item 1 of argv
	set folderPath to item 2 of argv
	set accountName to item 3 of argv
	set subjectPart to item 4 of argv
	set out to ""
	tell application "Mail"
		set acc to account accountName
		set mb to mailbox "INBOX" of acc
		set msgs to (messages of mb whose subject contains subjectPart and sender contains senderPart)
		repeat with m in msgs
			repeat with a in mail attachments of m
				set n to name of a
				set p to folderPath & "/" & n
				save a in my dest(p)
				set out to out & n & linefeed
			end repeat
		end repeat
	end tell
	return out
end run
