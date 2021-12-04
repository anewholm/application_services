#!/bin/bash
user="$USER"
if [ -n "$1" ]; then
	user=$1
	echo "Setting up supplied user $user"
else
	echo "Setting up current user $user"
fi

home_dir=/home/$user

if [ -f $home_dir/user-setup-success ]; then
	echo "File user-setup-success found in home directory. Not setting up again"
else
	# No-clobber will not overwrite any existing template
	sudo cp -r --no-clobber --no-dereference template/* $home_dir
	# Re-assure that the user owns their direct things
	# TODO: how does this affest symlinks?
	sudo chown -R $user:$user $home_dir/*

	# Link other users in to this one
	if [ ! -d /home/cal/calendars/$user ]; then
		ln -s $home_dir/calendars /home/cal/calendars/$user
	fi

	sudo touch $home_dir/user-setup-success
fi
