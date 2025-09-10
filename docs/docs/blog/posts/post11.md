---
date:
  created: 2023-12-31
  updated: 2024-01-02

categories:
  - Developers
tags:
  - Developers
authors:
  - jaseci
cover_image: images/post-11-1.jpg
title: "Setting Up Jaseci On Apple M1 Macs (ARM Processors)"
---

# Setting Up Jaseci On Apple M1 Macs (ARM Processors)

<!-- more -->

![Processor](../images/post-11-1.jpg){ width="60%" }

Core Jaseci and its built-in libraries run great on an M1 mac, with Rosetta enabled. However, using packages such as use_qa can result in errors such as Illegal instruction: 4, followed by python crashing and a VERY LONG list of errors, most of which you cannot make sense of…

![Code 1](../images/post-11-2.png)

## The Short (and Sweet) Way… Use Remote Actions

This is also my favorite method to use…

To load use_qa and other jaseci modules, you can use the remote modules set up by our Sifus. To do this, basically, replace `actions load module jaseci_kit.use_qa` with `actions load remote https://use-qa.jaseci.org`


![Code 2](../images/post-11-3.png)

And, that’s all folks…

Or is it? we are hardcore programmers and don’t feel satisfied using the “short & sweet way” of doing things, do we? So let’s look at…

## The Other Way

This is the fun way, that’ll require reading a host of documentation… which we’ll try to avoid… but then end up reading it through thoroughly after hours of avoiding reading the documentation…

So here’s that perfect setup we need to get this all up and running.

### Update Jaseci & Packages

Ensure you’re running the correct version of Python needed for the version of Jaseci you’re running, then update Jaseci & Jaseci Kit by running.

- `pip3 install jaseci --upgrade`
- `pip3 install jaseci-kit --upgrade`

### Tensorflow

Turns out, that Tensorflow does not work too nicely with the new ARM processors that apple is using and requires special versions to run on the new M1 processors… So you’d need to read this article from Apple: [https://developer.apple.com/metal/tensorflow-plugin/](https://developer.apple.com/metal/tensorflow-plugin/)

*Quick Note*: Ensure the TensorFlow version you’re installing matches the requirements of the Jaseci version you’re currently running, else it won’t work.

### Test Tensorflow

Ensure you test TensorFlow using the Jupyther example in the video above (start at the 5-minute mark if you installed Tensorflow from the article) to ensure that TensorFlow is running smoothly.
