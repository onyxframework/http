#!/usr/bin/env node
"use strict";

const shell = require("shelljs");
const path = require("path");
const got = require("got");

console.log("Fetching Git commit hash...");

const gitCommitRet = shell.exec("git rev-parse HEAD", {
  cwd: path.join(__dirname, "..")
});

if (0 !== gitCommitRet.code) {
  console.error("Error getting git commit hash");
  process.exit(-1);
}

const gitCommitHash = gitCommitRet.stdout.trim();

const gitSubjectRet = shell.exec(`git show -s --format=%s ${gitCommitHash}`, {
  cwd: path.join(__dirname, "..")
});

const gitCommitSubject = gitSubjectRet.stdout.trim();

const triggerBuild = (username, repo, branch) => {
  console.log(`Triggering ${username}/${repo}@${branch}...`);

  got.post(`https://api.travis-ci.org/repo/${username}%2F${repo}/requests`, {
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Travis-API-Version": "3",
      "Authorization": `token ${process.env.TRAVIS_API_TOKEN}`,
    },
    body: JSON.stringify({
      request: {
        message: `onyx-http@${gitCommitHash.substring(0, 7)} ${gitCommitSubject}`,
        branch: branch,
        config: {
          env: `ONYX_HTTP_COMMIT=${gitCommitHash}`
        }
      },
    }),
  })
  .then(() => {
    console.log(`Triggered ${username}/${repo}@${branch}`);
  })
  .catch((err) => {
    console.error(err);
    process.exit(-1);
  });
};

triggerBuild("vladfaust", "crystalworld", "master");
triggerBuild("vladfaust", "onyx-40-loc-distributed-chat", "master");
triggerBuild("vladfaust", "onyx-todo-json-api", "part-1");
triggerBuild("vladfaust", "onyx-todo-json-api", "part-2");
