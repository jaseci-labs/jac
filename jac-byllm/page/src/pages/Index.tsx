import React, { useState } from 'react';
import { ArrowRight, ExternalLink, Github, Download, BookOpen, Users, MessageCircle, ChevronDown, FileText, Info } from 'lucide-react';
import { ThemeProvider } from '../components/ThemeProvider';
import { Header } from '../components/Header';
import { CodeBlock } from '../components/CodeBlock';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';

// Import example images
import example1 from '../assets/example-1.png';
import example2 from '../assets/example-2.jpg';
import example3 from '../assets/example-3.jpg';
import example4 from '../assets/example-4.png';

//Import evaluation metrices images
import fig17 from '../assets/fig17.png';
import fig22 from '../assets/fig22.png';
import fig23 from '../assets/fig23.png';

import evaluationPECode from '../assets/evalPE.py?raw';
import evaluationDSPyCode from '../assets/evaldspy.py?raw';
import evaluationJacCode from '../assets/byllmeval.jac?raw';

// Import JAC examples
import firstexampleCode from '../assets/firstexample.jac?raw';
import firstexamplecodepython from '../assets/firstexample.py?raw';
import areyouaiCode from '../assets/areyouai.jac?raw';
import personalityfinderCode from '../assets/personalityfinder.jac?raw';
import wikisearchCode from '../assets/wikisearch.jac?raw';

const Index = () => {
  const [activeTab, setActiveTab] = useState('areyouai');

  const examples = [
    {
      title: 'RPG Game level generation',
      description: 'An LLM powered game world generation into a simple RPG.',
      image: example1,
      link: 'https://www.jac-lang.org/learn/examples/mtp_examples/rpg_game/'
    },
    {
      title: 'Agentic AI Chatbot',
      description: 'An agentic chatbot built using byLLM and MCP',
      image: example2,
      link: 'https://www.jac-lang.org/learn/examples/rag_chatbot/Overview/'
    },
    {
      title: 'Agentic Coding Agent (Jac-Aider)',
      description: 'A coding agent built on <a href="https://aider.chat/" target="_blank" rel="noopener noreferrer" className="text-primary underline hover:text-primary/80">aider</a> but all prompts replaced with byllm calls reducing more than 200 lines of code.',
      image: example3,
      link: 'https://github.com/jaseci-labs/Agentic-AI/tree/main/aider-genius'
    },
    {
      title: 'Jac-GPT',
      description: 'An agentic chatbot running of Jaseci (including byllm)',
      image: example4,
      link: 'https://jac-gpt.jaseci.org/'
    }
  ];

  const metricsData = [
    { model: 'GPT-4', accuracy: '94.2%', f1Score: '0.918', latency: '1.2s' },
    { model: 'Claude-3', accuracy: '92.8%', f1Score: '0.905', latency: '0.9s' },
    { model: 'Gemini Pro', accuracy: '91.5%', f1Score: '0.892', latency: '1.1s' },
    { model: 'LLaMA-2', accuracy: '89.3%', f1Score: '0.876', latency: '0.7s' }
  ];

  const modelSnippets = {
    areyouai: {
      description: 'A simple example showing how to build a Yes/No answering bot using byLLM',
      code: areyouaiCode,
    },
    personalityfinder: {
      description: 'Using custom types and enums as outputs without any parsing logic',
      code: personalityfinderCode,
    },
    wikisearch: {
      description: 'React Loop with tool usage for wikipedia search agent',
      code: wikisearchCode,
    }
  };

  return (
    <ThemeProvider>
      <div className="min-h-screen bg-background">
        <Header />

        {/* Hero Section */}
        <section className="relative overflow-hidden">
          <div className="container py-16 md:py-20">
            <div className="mx-auto max-w-4xl text-center animate-fade-in">
              <div className="flex items-center justify-center h-full mb-12">
                <div className="flex items-center space-x-4">
                  {/* Logo on the left */}
                  <img
                    src="/logo.png"
                    alt="byLLM Logo"
                    className="h-28 w-auto"
                  />

                  {/* Text on the right */}
                  <div className="flex flex-col">
                    <h1 className="text-5xl font-bold leading-tight bg-gradient-to-r from-foreground to-muted-foreground bg-clip-text text-transparent">
                      <strong>byLLM</strong>
                    </h1>
                    <p className="text-body-large text-muted-foreground mt-1">
                      Prompt No More!
                    </p>
                  </div>
                </div>
              </div>




              <div className="bg-card border rounded-xl p-8 mb-12 text-left max-w-3xl mx-auto">
                <p className="text-body leading-relaxed text-card-foreground">
                  <strong>byLLM</strong> is a lightweight framework that simplifies building AI-powered applications by eliminating much of the manual prompt engineering process. Using its Meaning-Typed Programming paradigm, developers can express intent directly in code, while byLLM automatically generates optimized prompts. This approach reduces development time, cuts down lines of code, and improves the accuracy of AI-driven tasks. byLLM integrates seamlessly with the <a href="https://jac-lang.org" target="_blank" rel="noopener noreferrer" className="text-primary underline hover:text-primary/80">Jaseci ecosystem</a>, but can also be used as a standalone Python library.

                </p>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Button
                  className="btn-hero group"
                  onClick={() => window.open('https://arxiv.org/abs/2405.08965', '_blank')}
                >
                  <FileText className="mr-2 h-5 w-5" />
                  Read Research Paper
                  <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
                </Button>
                <Button variant="outline" className="btn-secondary"
                  onClick={() => window.open('https://github.com/jaseci-labs/jaseci/tree/main/jac-byllm', '_blank')}
                >
                  <Github className="mr-2 h-4 w-4" />
                  View on GitHub
                </Button>
                <Button className="btn-hero group"
                  onClick={() => window.open('https://www.jac-lang.org/learn/jac-byllm/with_llm/', '_blank')}
                >
                  <BookOpen className="mr-2 h-4 w-4" />
                  View Docs
                  <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
                </Button>
              </div>
            </div>
          </div>
        </section>


        {/* Why by? Section */}
        <section className="py-12 bg-gradient-to-b from-background to-muted/20">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">Why byLLM?</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Built for developers who want to focus on building, not configuring
              </p>
            </div>

            <div className="grid gap-8 md:grid-cols-2 max-w-4xl mx-auto">
              <div className="group relative overflow-hidden rounded-2xl bg-card border border-border/50 p-8 hover:border-primary/20 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
                <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-primary/10 to-transparent rounded-full -translate-y-16 translate-x-16"></div>
                <div className="relative flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform duration-300">
                    <div className="text-2xl">🚀</div>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold mb-3">No Prompt Engineering</h3>
                    <p className="text-muted-foreground leading-relaxed">
                      Write natural function signatures and let byLLM handle prompt generation automatically. High accuracy right out of the box relative to DSPy and LMQL frameworks. 
                    </p>
                  </div>
                </div>
              </div>

              <div className="group relative overflow-hidden rounded-2xl bg-card border border-border/50 p-8 hover:border-primary/20 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
                <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-primary/10 to-transparent rounded-full -translate-y-16 translate-x-16"></div>
                <div className="relative flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform duration-300">
                    <div className="text-2xl">➕</div>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold mb-3"> Minimal Code Changes</h3>
                    <p className="text-muted-foreground leading-relaxed">
                      A simple by keyword, all the complexity of prompt engineering and output parsing is hidden. Switch or integrate LLMs using just one line of code.
                    </p>
                  </div>
                </div>
              </div>

              <div className="group relative overflow-hidden rounded-2xl bg-card border border-border/50 p-8 hover:border-primary/20 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
                <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-primary/10 to-transparent rounded-full -translate-y-16 translate-x-16"></div>
                <div className="relative flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform duration-300">
                    <div className="text-2xl">🔧</div>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold mb-3">Rapid Agentic AI Development</h3>
                    <p className="text-muted-foreground leading-relaxed">
                      Leverage the broader Jaseci ecosystem to quickly build and scale agentic AI applications.
                    </p>
                  </div>
                </div>
              </div>

              <div className="group relative overflow-hidden rounded-2xl bg-card border border-border/50 p-8 hover:border-primary/20 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
                <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-primary/10 to-transparent rounded-full -translate-y-16 translate-x-16"></div>
                <div className="relative flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform duration-300">
                    <div className="text-2xl">🌐</div>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold mb-3">Model Agnostic</h3>
                    <p className="text-muted-foreground leading-relaxed">
                      Works with any LLM provider - OpenAI, Anthropic, Google, or your own hosted models. Switch easily between providers.
                    </p>
                  </div>
                </div>
              </div>

            </div>
          </div>
        </section>

        {/* Getting Started Section */}
        <section id="install" className="py-12 bg-muted/30">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">Getting Started</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Install <strong>byLLM</strong> and start building AI applications in minutes
              </p>
            </div>

            <div className="max-w-4xl mx-auto">
              <CodeBlock code="pip install byllm" language="bash" />
              <div className="bg-gradient-to-r from-primary/5 to-primary/10 border border-primary/20 rounded-lg p-4 mt-2 mb-8">
                <div className="flex items-center gap-2 mb-1">
                  <Info className="h-4 w-4 text-primary" />
                  <span className="font-medium text-sm text-primary">Note</span>
                </div>
                <p className="text-sm text-muted-foreground ml-6">You'll need access to a language model, either via an API provider or a locally hosted model. Make sure to save your API key as a secret in your environment variables. For example:</p>
                <CodeBlock code="export OPENAI_API_KEY='your-api-key'" language="bash" />
              </div>

              <div className="text-center mb-16">
              <h4 className="text-section mb-4">How to use byLLM?</h4>
            </div>

          <div className="max-w-4xl mx-auto mb-8">
              <Tabs defaultValue="jac" className="w-full">
                <TabsList className="grid w-full grid-cols-2 mb-4">
                  <TabsTrigger value="jac">Jac</TabsTrigger>
                  <TabsTrigger value="python">Python</TabsTrigger>
                </TabsList>
                <TabsContent value="jac">
                  <CodeBlock code={firstexampleCode} language="jac" />
                </TabsContent>
                <TabsContent value="python">
                  <CodeBlock code={firstexamplecodepython} language="python" />
                </TabsContent>
              </Tabs>
            </div>

              <div className="text-center mb-16">
              <p className="text-base font-semibold italic text-primary mb-4">IT IS THAT SIMPLE!</p>
            </div>

              <div className="text-center mb-8">
                <h3 className="text-section mb-4">Let's look at some simple examples to understand how byLLM is used.</h3>
              </div>

              <div className="bg-gradient-to-r from-primary/5 to-primary/10 border border-primary/20 rounded-lg p-4 mt-2 mb-8">
                <div className="flex items-center gap-2 mb-1">
                  <Info className="h-4 w-4 text-primary" />
                  <span className="font-medium text-sm text-primary">Note</span>
                </div>
                <p className="text-sm text-muted-foreground ml-6">The Model class in byLLM serves as an interface to <a href="https://docs.litellm.ai/docs/providers" target="_blank" rel="noopener noreferrer" className="text-primary underline hover:text-primary/80">LiteLLM</a>. This means any model supported by LiteLLM can be used with byLLM. When configuring a model, refer to the LiteLLM documentation to see which variables are required, and pass those same variables to Model in byLLM.</p>
              </div>

              <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
                <TabsList className="grid w-full grid-cols-2 md:grid-cols-3 mb-8">
                  <TabsTrigger value="areyouai">AreYouAI</TabsTrigger>
                  <TabsTrigger value="personalityfinder">PersonalityFinder</TabsTrigger>
                  <TabsTrigger value="wikisearch">WikiSearch</TabsTrigger>
                </TabsList>

                {Object.entries(modelSnippets).map(([key, snippet]) => (
                  <TabsContent key={key} value={key} className="space-y-6">
                    <Card className="card-interactive">
                      <CardContent className="p-8">
                        <p className="text-body text-muted-foreground mb-6">
                          {snippet.description}
                        </p>
                        <CodeBlock code={snippet.code} language="jac" />
                      </CardContent>
                    </Card>
                  </TabsContent>
                ))}
              </Tabs>
            </div>
          </div>
        </section>


        {/* Projects Section */}
        <section id="projects" className="py-12 bg-muted/30">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">Projects</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Explore real-world applications and get inspired by what's possible
              </p>
            </div>

            <div className="grid gap-6 md:grid-cols-1 lg:grid-cols-2 max-w-3xl mx-auto">
              {examples.map((example, index) => (
                <Card
                  key={index}
                  className="card-interactive group cursor-pointer overflow-hidden"
                  onClick={() => window.open(example.link, '_blank')}
                >
                  <div className="aspect-video overflow-hidden">
                    <img
                      src={example.image}
                      alt={example.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-lg">{example.title}</CardTitle>
                      <ExternalLink className="h-4 w-4 text-muted-foreground group-hover:text-primary transition-colors" />
                    </div>
                    <CardDescription dangerouslySetInnerHTML={{ __html: example.description }} />
                    {/* <CardDescription>{example.description}</CardDescription> */}
                  </CardHeader>
                </Card>
              ))}
            </div>
          </div>
        </section>

        {/* Evaluation Metrics */}
        {/* <section className="py-12">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">Evaluation Metrics</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Performance comparison across different language models
              </p>
            </div>

            <div className="max-w-4xl mx-auto">
              <Card>
                <CardContent className="p-6">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b">
                          <th className="text-left py-4 px-4 font-semibold">Model</th>
                          <th className="text-left py-4 px-4 font-semibold">Accuracy</th>
                          <th className="text-left py-4 px-4 font-semibold">F1 Score</th>
                          <th className="text-left py-4 px-4 font-semibold">Latency</th>
                        </tr>
                      </thead>
                      <tbody>
                        {metricsData.map((metric, index) => (
                          <tr key={index} className="border-b last:border-b-0 hover:bg-muted/50 transition-colors">
                            <td className="py-4 px-4 font-medium">{metric.model}</td>
                            <td className="py-4 px-4 text-primary font-semibold">{metric.accuracy}</td>
                            <td className="py-4 px-4">{metric.f1Score}</td>
                            <td className="py-4 px-4 text-muted-foreground">{metric.latency}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </section> */}
        
        {/* How Users React to byLLM */}
        <section className="py-12">
          <div className="container">
            <div className="text-center mb-12">
              <h2 className="text-section mb-4">How Users React to byLLM</h2>
            </div>
            <div className="flex flex-col items-center">
              <img
                src={fig17}
                alt="User reactions to byLLM"
                className="max-h-96 w-auto object-contain rounded-lg shadow-md"
              />
              <div className="text-sm text-muted-foreground mt-4 text-center max-w-xl">
                User evaluation of LMQL, DSPy and MTPon five usability criteria
              </div>
            </div>
          </div>
        </section>

        {/* Runtime Speed and Cost Improvements */}
        
<section className="py-12">
  <div className="container">
    <div className="text-center mb-16">
      <h2 className="text-section mb-8">Evaluation Metrices</h2>
      <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
        Comparison of runtime performance and cost efficiency across frameworks
      </p>
    </div>

    
    {/* Figures */}
<div className="grid md:grid-cols-2 gap-8 max-w-5xl mx-auto mb-4">
  <Card>
    <CardContent className="p-4 flex flex-col items-center justify-center">
      <img
        src={fig22}
        alt="Figure 22: Runtime Speed Comparison"
        className="max-h-72 w-auto object-contain"
      />
      <div className="text-xs text-muted-foreground mt-2 text-center">
        Token usage comparison between MTP and DSPy.
      </div>
    </CardContent>
  </Card>
  <Card>
    <CardContent className="p-4 flex flex-col items-center justify-center">
      <img
        src={fig23}
        alt="Figure 23: Cost Efficiency Comparison"
        className="max-h-72 w-auto object-contain"
      />
      <div className="text-xs text-muted-foreground mt-2 text-center">
        Cost and runtime speed comparison between MTP and DSPy.
      </div>
    </CardContent>
  </Card>
</div>
<div className="text-center mb-16">
  <span className="text-base font-semibold text-primary">
    Lower latency and cost on average
  </span>
</div>

{/* Code Examples Section */}
<div className="grid md:grid-cols-2 gap-8 max-w-6xl mx-auto items-start">

  {/* Title below the grid */}
  <div className="col-span-2 mb-4">
    <h3 className="text-section text-center font-bold text-2xl">
      Side-by-side code comparison
    </h3>
  </div>
  
  {/* Left Tabs */}
  <div>
    <Tabs defaultValue="jac" className="w-full">
      <TabsList className="grid w-full grid-cols-2 mb-4">
        <TabsTrigger value="jac">Prompt Engineering</TabsTrigger>
        <TabsTrigger value="python">DSPy</TabsTrigger>
      </TabsList>
      <TabsContent value="jac">
        <Card>
          <CardContent className="p-4">
            <CodeBlock code={evaluationPECode} language="python" />
          </CardContent>
        </Card>
      </TabsContent>
      <TabsContent value="python">
        <Card>
          <CardContent className="p-4">
            <CodeBlock code={evaluationDSPyCode} language="python" />
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>
  </div>

  {/* Right Jac Tab */}
  <div>
    <Tabs defaultValue="jac-impl" className="w-full">
      <TabsList className="grid w-full grid-cols-1 mb-4">
        <TabsTrigger value="jac-impl">Jac Implementation</TabsTrigger>
      </TabsList>
      <TabsContent value="jac-impl">
        <Card>
          <CardContent className="p-4">
            <CodeBlock code={evaluationJacCode} language="jac" />
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>
  </div>
</div>


  </div>
</section>


        {/* How it Works */}
        {/* <section className="py-12 bg-muted/30">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">How it Works</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Get up and running with <strong>byLLM</strong> in three simple steps
              </p>
            </div>

            <div className="max-w-4xl mx-auto space-y-16">
              <div className="flex items-start gap-8">
                <div className="h-12 w-12 bg-primary text-primary-foreground rounded-full flex items-center justify-center flex-shrink-0 text-xl font-bold">
                  1
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold mb-4">Install & Setup</h3>
                  <p className="text-body text-muted-foreground mb-6">
                    Install <strong>byLLM</strong> and configure your preferred models to get started quickly
                  </p>
                  <CodeBlock
                    code="pip install by-llm\nby-llm init my-project\ncd my-project"
                    language="bash"
                  />
                </div>
              </div>

              <div className="flex items-start gap-8">
                <div className="h-12 w-12 bg-primary text-primary-foreground rounded-full flex items-center justify-center flex-shrink-0 text-xl font-bold">
                  2
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold mb-4">Define Modules</h3>
                  <p className="text-body text-muted-foreground mb-6">
                    Create reusable AI modules with natural language descriptions that define their behavior
                  </p>
                  <CodeBlock
                    code='from by_llm import Module\n\nclass Summarizer(Module):\n    """Summarize text concisely"""\n    pass'
                    language="python"
                  />
                </div>
              </div>

              <div className="flex items-start gap-8">
                <div className="h-12 w-12 bg-primary text-primary-foreground rounded-full flex items-center justify-center flex-shrink-0 text-xl font-bold">
                  3
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold mb-4">Compose & Execute</h3>
                  <p className="text-body text-muted-foreground mb-6">
                    Chain modules together to build complex applications with simple composition
                  </p>
                  <CodeBlock
                    code='pipeline = Summarizer() >> Translator()\nresult = pipeline("Long text...")\nprint(result)'
                    language="python"
                  />
                </div>
              </div>
            </div>
          </div>
        </section> */}

        {/* Documentation CTA */}
        <section id="documentation" className="py-12">
          <div className="container text-center">
            <h2 className="text-section mb-4">Ready to dive deeper?</h2>
            <p className="text-body-large text-muted-foreground mb-8 max-w-2xl mx-auto">
              Explore our comprehensive documentation to unlock the full potential of byLLM
            </p>
            <a
              href="https://www.jac-lang.org/learn/jac-byllm/with_llm/"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button className="btn-hero text-lg px-8 py-4">
                <BookOpen className="mr-2 h-5 w-5" />
                See Documentation
                <ArrowRight className="ml-2 h-5 w-5" />
              </Button>
            </a>
          </div>
        </section>

        

        {/* References */}
        <section className="py-12">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">References</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Research and academic foundations
              </p>
            </div>

            <div className="max-w-4xl mx-auto">
              <Card>
                <CardContent className="p-8">
                  <div className="space-y-6">
                    <div className="border-l-4 border-primary pl-6">
                      <p className="text-sm text-muted-foreground mt-2">
                        Jayanaka L. Dantanarayana, Yiping Kang, Kugesan Sivasothynathan, Christopher Clarke, Baichuan Li, Savini Kashmira, Krisztian Flautner, Lingjia Tang, and Jason Mars. 2025
                      </p>
                      <p className="text-body italic text-muted-foreground">
                        "MTP: A Meaning-Typed Language Abstraction for AI-Integrated Programming." : Proc. ACM Program. Lang. 9, OOPSLA2, Article 314 (October 2025), 29 pages.{" "}
                        <a
                          href="https://doi.org/10.1145/3763092"
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-primary underline hover:text-primary/80"
                        >
                          https://doi.org/10.1145/3763092
                        </a>
                      </p>
                    </div>

                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        {/* Footer */}
        <footer id="community" className="border-t bg-card">
          <div className="container py-16">
            <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
              <div>
                {/* <div className="flex items-center space-x-2 mb-4">
                  <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center">
                    <span className="text-primary-foreground font-bold text-sm">BL</span>
                  </div>
                  <span className="text-xl font-semibold">byLLM</span>
                </div> */}
                <div className="flex items-center space-x-2 mb-4">
                  <img
                    src="/logo.png"
                    alt="byLLM Logo"
                    className="h-8 w-auto rounded-lg bg-primary"
                    style={{ background: 'none' }}
                  />
                  <span className="text-xl font-semibold">byLLM</span>
                </div>
                <p className="text-muted-foreground text-sm">
                  Building the future of AI development with declarative, composable frameworks.
                </p>
              </div>

              <div>
                <h4 className="font-semibold mb-4">Community</h4>
                <ul className="space-y-2 text-sm">
                  <li>
                    <a href="https://discord.gg/6j3QNdtcN6" target="_blank" className="text-muted-foreground hover:text-primary transition-colors flex items-center">
                      <MessageCircle className="h-4 w-4 mr-2" />
                      Discord Server
                    </a>
                  </li>
                </ul>
              </div>

              <div>
                <h4 className="font-semibold mb-4">Resources</h4>
                <ul className="space-y-2 text-sm">
                  <li>
                    <a href="https://www.jac-lang.org/learn/jac-byllm/with_llm/" target="_blank" className="text-muted-foreground hover:text-primary transition-colors">
                      Documentation
                    </a>
                  </li>
                  <li>
                    <a href="https://github.com/jaseci-labs/jaseci/tree/main/jac-byllm/examples" target="_blank" className="text-muted-foreground hover:text-primary transition-colors">
                      Projects
                    </a>
                  </li>
                  {/* <li>
                    <a href="#" target="_blank" className="text-muted-foreground hover:text-primary transition-colors">
                      Tutorials
                    </a>
                  </li> */}
                </ul>
              </div>

              <div>
                <h4 className="font-semibold mb-4">FAQ</h4>
                <ul className="space-y-2 text-sm">
                  {/* <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Getting Started
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Model Support
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Troubleshooting
                    </a>
                  </li> */}
                  <li>
                    <a href="https://www.jac-lang.org/internals/contrib/" target="_blank" className="text-muted-foreground hover:text-primary transition-colors">
                      Contributing
                    </a>
                  </li>
                </ul>
              </div>
            </div>

            <div className="border-t mt-12 pt-8 text-center text-sm text-muted-foreground">
              <p>&copy; 2025 byLLM Project. Built with passion for the AI development community.</p>
            </div>
          </div>
        </footer>
      </div>
    </ThemeProvider>
  );
};

export default Index;