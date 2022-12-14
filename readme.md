# Complex App for Fibonacci Sequence

## Generating React App
Lesson 115 & 116 - updated 8-4-2020

In the next lecture, Stephen will be going over how to install Create React App globally and generate the application. This method of generating a React project is no longer recommended.

Instead of this:
```
npm install -g create-react-app
create-react-app client
```

We need to run this command:
```
npx create-react-app client
```

Important Reminder:
Once you have generated the React app you will need to delete the local git repository that Create React App may have automatically initialized.
Inside the newly created client directory, run `rm -r .git`.
If you miss this step, the client folder will be considered a submodule and pushed as an empty folder to GitHub.

Documentation:

https://create-react-app.dev/docs/getting-started#npx

If you've previously installed create-react-app globally via `npm install -g create-react-app`, we recommend you uninstall the package using `npm uninstall -g create-react-app` to ensure that npx always uses the latest version.