Shell = require 'shell'
{Range} = require 'atom'

module.exports =
class SimpleGitHubFile

  # Public
  @fromPath: (filePath) ->
    new GitHubFile(filePath)

  # Internal
  constructor: (@filePath) ->
    #@repo = atom.project.getRepositories()?[0]

  # Public
  open: ->
    if @isOpenable()
      @openUrlInBrowser(@blobUrl())
    else
      @reportValidationErrors()

  # Public
  blame: (lineRange) ->
    if @isOpenable()
      @openUrlInBrowser(@blameUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  history: (lineRange) ->
    if @isOpenable()
      @openUrlInBrowser(@historyUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  copyUrl: (lineRange) ->
    if @isOpenable()
      url = @blobUrl()
      atom.clipboard.write(url + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  getLineRangeSuffix: (lineRange) ->
    if lineRange and atom.config.get('open-on-github.includeLineNumbersInUrls')
      lineRange = Range.fromObject(lineRange)
      startRow = lineRange.start.row + 1
      endRow = lineRange.end.row + 1
      if startRow is endRow
        "#L#{startRow}"
      else
        "#L#{startRow}-L#{endRow}"
    else
      ''

  # Public
  isOpenable: ->
    @validationErrors().length == 0

  # Public
  validationErrors: ->
    unless @gitUrl()
      return ["No URL defined for remote (#{@remoteName()})"]

    unless @githubRepoUrl()
      return ["Remote URL is not hosted on GitHub.com (#{@gitUrl()})"]

    []

  # Internal
  reportValidationErrors: ->
    atom.beep()
    console.warn error for error in @validationErrors()

  # Internal
  openUrlInBrowser: (url) ->
    Shell.openExternal url

  # Internal
  blobUrl: ->
    "#{@githubRepoUrl()}/blob/#{@branch()}/#{@repoRelativePath()}"

  # Internal
  blameUrl: ->
    "#{@githubRepoUrl()}/blame/#{@branch()}/#{@repoRelativePath()}"

  # Internal
  historyUrl: ->
    "#{@githubRepoUrl()}/commits/#{@branch()}/#{@repoRelativePath()}"

  getRepo: ->
    atom.project.getRepositories()?[0]

  # Internal
  gitUrl: ->
    remoteOrBestGuess = @remoteName() ? 'origin'
    @getRepo()?.getConfigValue("remote.#{remoteOrBestGuess}.url")

  # Internal
  githubRepoUrl: ->
    return unless url = @gitUrl()
    if url.match /https:\/\/[^\/]+\// # e.g., https://github.com/foo/bar.git
      url.replace(/\.git$/, '')
    else if url.match /git@[^:]+:/    # e.g., git@github.com:foo/bar.git
      url.replace /^git@([^:]+):(.+)$/, (match, host, repoPath) ->
        "http://#{host}/#{repoPath}".replace(/\.git$/, '')
    else if url.match /^git:\/\/[^\/]+\// # e.g., git://github.com/foo/bar.git
      "http#{url.substring(3).replace(/\.git$/, '')}"

  # Internal
  repoRelativePath: ->
    @getRepo()?.relativize(@filePath)

  # Internal
  remoteName: ->
    # e.g., "refs/remotes/origin/master"
    refName = @getRepo()?.getUpstreamBranch()
    refName?.match(/^refs\/remotes\/(.+)\/.*$/)?[1] ? null

  # Internal
  branch: ->
    # e.g., "refs/remotes/origin/master"
    refName = @getRepo()?.getUpstreamBranch()
    refName?.match(/^refs\/remotes\/.*\/(.+)$/)?[1] ? @repo.getShortHead()
