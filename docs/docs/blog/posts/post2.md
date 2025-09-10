---
date:
  created: 2023-12-31
  updated: 2024-01-02
categories:
  - Developers
tags:
  - Developers
authors:
  - forbes
cover_image: images/post-2.jpg
title: "A Whale of a Tale: The Size-Matters Misconception For Generative AI"
---

# A Whale of a Tale: The Size-Matters Misconception For Generative AI

<!-- more -->

![Jason Mars talks](../images/post-2.jpg)

In this new age of generative AI, everyone has made a major assumption for which a pressing question has emerged. You can see this manifesting in certain nerdy corners of social media.

This screenshot of Reddit and Twitter posts shows the rising curiosity about the effectiveness of small, open-source models versus their large, proprietary counterparts. Indeed, in this noisy market, there is widespread confusion and curiosity surrounding this topic. The narrative that “bigger is inherently better” is about to be challenged.

![_Is bigger necessarily better when it comes to AI models? Maybe not.](../images/post-2.1.png){ width="60%" }

_Is bigger necessarily better when it comes to AI models? Maybe not._

Well, along with my amazing colleagues at the University of Michigan and Jaseci Labs, we’ve delved into this very question in a rigorous and scholarly way. We’ve produced the first academic paper that addresses the debate head-on, to be presented in the prestigious ISPASS 2024 proceedings.

Our findings are not just surprising; they are a call to rethink what we know about the size of AI models we should be relying on in production and commercial use cases, and the efficiency we can achieve.

## Two Major AI Contenders

So, let’s talk about the two contenders, the Large Language Models (GPT4 and friends) vs the Small Language Models. Open AI has published GPT4 models that are at least 540 gigabytes, while the small and open-source models we study in the paper are around three gigabytes. That’s around 200 times smaller.

To illustrate the comparison, imagine GPT-4 as the blue whale, the largest animal on the planet, weighing up to about 200 tons. Now, contrast this with a housefly, a creature so small it’s easy to overlook, weighing in at a mere 12 milligrams.

These houseflies would be our models like LLaMA-7b quantized, Mistral-7b quantized, and Starling-LM-7b quantized — smaller, open-source alternatives poised to challenge the notion that bigger always means better. This comparison represents the difference in scale between the models we study in the paper.

The core discovery in the paper is simple: the belief that one must wield a GPT-4-sized model to achieve significant results is a myth.

## Our Approach

Our research was conducted with open and quantized models and gpt4 itself. Our investigation was centered around a case study with the commercial Myca.ai product, a productivity tool enhanced by AI to deliver personalized pep talks based on your productivity. The results, as detailed in our paper, are nothing short of shocking even to us.

We asked three simple questions. Can end users tell a quality loss in response when using the housefly models? How much faster are the AI responses with the smaller open models? And how much cheaper is it?

## On Quality

![Response quality of GPT-4 and SLMs as rated by human reviewers.](../images/post-2.2.png){ width="40%" }

_Response quality of GPT-4 and SLMs as rated by human reviewers._

When participants were subjected to a blind test comparing the output of large proprietary models against that of smaller, open-source models, the results were revelatory. Like the famed Pepsi/Coke taste tests, users were hard-pressed to discern which model produced the output. Indeed, much of the time, OpenAI’s GPT4 was not selected or scored very poorly. GPT4 was selected as the better output only around half the time than an SLM. For many (perhaps most) practical product use cases, SLMs do not only as well as sometimes even better than generalized proprietary LLMs. This result underscored the competency of smaller models in delivering quality content indistinguishable from their larger counterparts.

## On Speed

Further analysis revealed that these smaller models are up to 10 times faster than GPT-4 on our own machines in an AWS cluster and offer greater reliability. The latency of response was consistent all day long.

And Myca.ai didn’t suffer from the outages that OpenAI has become known for. Given that our housefly models are not tethered to the operational integrity of any single provider, they remain unaffected by these outages that can impact any of the larger, proprietary models.

## On Cost

Perhaps most compelling is the cost advantage. Our research indicates that deploying small, open models can be anywhere from five to 23 times cheaper than relying on a model like GPT-4. This range represents a worst-case to best-case scenario, highlighting the substantial financial benefits that come with adopting smaller models.

## The Groundbreaking Insight

When you opt for smaller, more accessible models, you not only gain control but also empower yourself with the ability to tailor the technology to your needs. Businesses, for example, can take these open-source models and adapt them, even going as far as training them in-house, without the prohibitive costs associated with larger models.

Our findings invite a paradigm shift in how we approach the development and deployment of AI models. The evidence is clear: smaller, open-source models not only stand toe-to-toe with their gargantuan counterparts in terms of intelligence and capability but also offer critical advantages.

Indeed, Jaseci Labs is now helping businesses tailor their own small models for game-changing product use cases, leading to what may be a major description of the OpenAIs and Anthropics of the world.

We encourage you to delve into the peer-reviewed analysis presented in our paper. Let the truth behind this rigorous analysis guide your decisions as you navigate the future of AI, and consider how embracing smaller models could not only enhance your technological endeavors but also democratize access to this groundbreaking field.

This article was originally posted on Forbes.com, click the link below to read the complete article.

[Read the full article on Forbes](https://www.forbes.com/sites/forbesbooksauthors/2024/03/21/a-whale-of-a-tale-the-size-matters-misconception-for-generative-ai/?sh=40121c8c581a)
