module.exports = {
  printWidth: 400,
  singleQuote: true,
  trailingComma: 'es5',
  jsxBracketSameLine: false,
  semi: true,
  arrowParens: 'always',
  overrides: [
    {
      files: '*.scss',
      options: {
        singleQuote: false,
      },
    },
    {
      files: '*.sol',
      options: {
        singleQuote: false,
      },
    },
  ],
};
