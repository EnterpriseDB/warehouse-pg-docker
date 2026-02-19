# Get a token:
# - go to https://enterprisedb.com/
# - Sign in
# - Go to "My Account" (in the upper right corner)
# - Select "Account Settings" from Dropdown
# - Under "Profile", cope the first line, that's the "Repos 2.0" token
# - Create the file "~/.edb-token" and copy the token into the file


EDBTOKENFILE := ~/.edb-token
EDBREPOSITORYFILE := ~/.edb-repository
ifeq ($(wildcard $(EDBTOKENFILE)),)
$(error Required file '$(EDBTOKENFILE)' not found. Please create tokenfile first.)
endif
ifeq ($(wildcard $(EDBREPOSITORYFILE)),)
$(error Required file '$(EDBREPOSITORYFILE)' not found. Please create repositoryfile first.)
endif
export EDBTOKEN := $(shell cat ~/.edb-token | head -n 1)
# Pick one: dev, staging_gpsupp, gpsupp
export EDBREPOSITORY := $(shell cat ~/.edb-repository | head -n 1)

ifeq ($(EDBTOKEN),)
$(error "EDBTOKEN is not set. Please add ~/.edb-token!")
endif
ifeq ($(EDBREPOSITORY),)
$(error "EDBREPOSITORY is not set. Please add ~/.edb-repository!")
endif
