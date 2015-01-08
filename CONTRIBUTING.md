# Contributing to ActiveShipping

We welcome fixes and additions to this project. Fork this project, make your changes and submit a pull request!

### Code style

Please use clean, concise code that follows Ruby community standards. For example:

- Be consistent
- Don't use too much white space
  - Use 2 space indent, no tabs.
  - No spaces after (, [ and before ],)
- Nor too little
  - Use spaces around operators and after commas, colons and semicolons
  - Indent when as deep as case
- Write lucid code in lieu of adding comments

### Pull request guidelines

- Add unit tests, and remote tests to make sure we won't introduce regressions to your code later on.
- Make sure CI passes for all Ruby versions and dependency versions we support.
- XML handling: use `REXML` for parsing XML, and `builder` to generate it.
- JSON: use the JSON module that is included in Rubys standard ibrary
- HTTP: use `ActiveUtils`'s `PostsData`.
- Do not add new gem dependencies.

### Contributors

- James MacAulay (<http://jmacaulay.net>)
- Tobias Luetke (<http://blog.leetsoft.com>)
- Cody Fauser (<http://codyfauser.com>)
- Jimmy Baker (<http://jimmyville.com/>)
- William Lang (<http://williamlang.net/>)
- Cameron Fowler
- Christopher Saunders (<http://christophersaunders.ca>)
- Denis Odorcic
- Dennis O'Connor
- Dennis Theisen
- Edward Ocampo-Gooding
- Isaac Kearse
- John Duff
- Nigel Ramsay
- Philip Arndt
- Vikram Oberoi
- Willem van Bergen
