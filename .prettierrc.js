module.exports = {
  plugins: ['prettier-plugin-solidity'],
  singleQuote: true,
  bracketSpacing: true,
  semi: false,
  overrides: [
    {
      files: '*.sol',
      options: {
        parser: 'solidity-parse',
        printWidth: 79,
        tabWidth: 4,
        singleQuote: false,
      },
    },
  ],
}
