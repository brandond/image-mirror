.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/v0.4.2/dapper-$$(uname -s)-$$(uname -m) > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

mirror: .dapper
	./.dapper --debug

.DEFAULT_GOAL := mirror

.PHONY: mirror
