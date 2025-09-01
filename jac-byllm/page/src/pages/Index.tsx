import React, { useState } from 'react';
import { ArrowRight, ExternalLink, Github, Download, BookOpen, Users, MessageCircle, ChevronDown, FileText } from 'lucide-react';
import { ThemeProvider } from '../components/ThemeProvider';
import { Header } from '../components/Header';
import { CodeBlock } from '../components/CodeBlock';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';

// Import example images
import example1 from '../assets/example-1.jpg';
import example2 from '../assets/example-2.jpg';
import example3 from '../assets/example-3.jpg';
import example4 from '../assets/example-4.jpg';
import example5 from '../assets/example-5.jpg';

const Index = () => {
  const [activeTab, setActiveTab] = useState('openai');

  const examples = [
    {
      title: 'Code Generation',
      description: 'Generate clean, efficient code with natural language prompts',
      image: example1,
      link: 'https://github.com/by-llm/code-generation'
    },
    {
      title: 'Model Training',
      description: 'Train and fine-tune language models with ease',
      image: example2,
      link: 'https://github.com/by-llm/model-training'
    },
    {
      title: 'NLP Workflows',
      description: 'Build sophisticated natural language processing pipelines',
      image: example3,
      link: 'https://github.com/by-llm/nlp-workflows'
    },
    {
      title: 'API Integration',
      description: 'Seamlessly integrate with various language model APIs',
      image: example4,
      link: 'https://github.com/by-llm/api-integration'
    },
    {
      title: 'Research Tools',
      description: 'Advanced tools for academic research and analysis',
      image: example5,
      link: 'https://github.com/by-llm/research-tools'
    }
  ];

  const metricsData = [
    { model: 'GPT-4', accuracy: '94.2%', f1Score: '0.918', latency: '1.2s' },
    { model: 'Claude-3', accuracy: '92.8%', f1Score: '0.905', latency: '0.9s' },
    { model: 'Gemini Pro', accuracy: '91.5%', f1Score: '0.892', latency: '1.1s' },
    { model: 'LLaMA-2', accuracy: '89.3%', f1Score: '0.876', latency: '0.7s' }
  ];

  const modelSnippets = {
    openai: {
      description: 'Use this LLM model with OpenAI\'s powerful GPT models',
      code: 'pip install by-llm[openai]\n# Set your API key\nexport OPENAI_API_KEY="your-api-key"\n\n# Usage\nfrom by_llm import OpenAI\nmodel = OpenAI()\nresult = model.generate("Hello world")'
    },
    gemini: {
      description: 'Use this LLM model with Google\'s advanced Gemini models',
      code: 'pip install by-llm[gemini]\n# Set your API key\nexport GEMINI_API_KEY="your-api-key"\n\n# Usage\nfrom by_llm import Gemini\nmodel = Gemini()\nresult = model.generate("Hello world")'
    },
    claude: {
      description: 'Use this LLM model with Anthropic\'s sophisticated Claude models',
      code: 'pip install by-llm[anthropic]\n# Set your API key\nexport ANTHROPIC_API_KEY="your-api-key"\n\n# Usage\nfrom by_llm import Claude\nmodel = Claude()\nresult = model.generate("Hello world")'
    },
    deepseek: {
      description: 'Use this LLM model with DeepSeek\'s efficient and capable models',
      code: 'pip install by-llm[deepseek]\n# Set your API key\nexport DEEPSEEK_API_KEY="your-api-key"\n\n# Usage\nfrom by_llm import DeepSeek\nmodel = DeepSeek()\nresult = model.generate("Hello world")'
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
              <h1 className="text-hero mb-6 bg-gradient-to-r from-foreground to-muted-foreground bg-clip-text text-transparent">
                By LLM
              </h1>
              
              <p className="text-body-large text-muted-foreground mb-8 max-w-2xl mx-auto">
                A declarative framework for building modular AI software. Create sophisticated language model applications with clean, composable code.
              </p>
              
              <div className="bg-card border rounded-xl p-8 mb-12 text-left max-w-3xl mx-auto">
                <p className="text-body leading-relaxed text-card-foreground">
                  By LLM enables developers to build AI applications using natural language modules that can be generically composed with different models, inference strategies, and learning algorithms. This makes AI software more reliable, maintainable, and portable across models and strategies. Think of it as a higher-level language for AI programming, similar to the evolution from assembly to modern programming languages.
                </p>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Button 
                  className="btn-hero group"
                  onClick={() => window.open('https://www.paper.com', '_blank')}
                >
                  <FileText className="mr-2 h-5 w-5" />
                  Read Research Paper
                  <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
                </Button>
                <Button variant="outline" className="btn-secondary">
                  <Github className="mr-2 h-4 w-4" />
                  View on GitHub
                </Button>
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
                Install By LLM and start building AI applications in minutes
              </p>
            </div>

            <div className="max-w-4xl mx-auto">
              <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
                <TabsList className="grid w-full grid-cols-2 md:grid-cols-4 mb-8">
                  <TabsTrigger value="openai">OpenAI</TabsTrigger>
                  <TabsTrigger value="gemini">Gemini</TabsTrigger>
                  <TabsTrigger value="claude">Claude</TabsTrigger>
                  <TabsTrigger value="deepseek">DeepSeek</TabsTrigger>
                </TabsList>
                
                {Object.entries(modelSnippets).map(([key, snippet]) => (
                  <TabsContent key={key} value={key} className="space-y-6">
                    <Card className="card-interactive">
                      <CardContent className="p-8">
                        <p className="text-body text-muted-foreground mb-6">
                          {snippet.description}
                        </p>
                        <CodeBlock code={snippet.code} language="python" />
                      </CardContent>
                    </Card>
                  </TabsContent>
                ))}
              </Tabs>
            </div>
          </div>
        </section>

        {/* Evaluation Metrics */}
        <section className="py-12">
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
        </section>

        {/* How it Works */}
        <section className="py-12 bg-muted/30">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">How it Works</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Get up and running with By LLM in three simple steps
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
                    Install By LLM and configure your preferred models to get started quickly
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
        </section>

        {/* Documentation CTA */}
        <section id="documentation" className="py-12">
          <div className="container text-center">
            <h2 className="text-section mb-4">Ready to dive deeper?</h2>
            <p className="text-body-large text-muted-foreground mb-8 max-w-2xl mx-auto">
              Explore our comprehensive documentation to unlock the full potential of By LLM
            </p>
            <Button className="btn-hero text-lg px-8 py-4">
              <BookOpen className="mr-2 h-5 w-5" />
              See Documentation
              <ArrowRight className="ml-2 h-5 w-5" />
            </Button>
          </div>
        </section>

        {/* Examples Section */}
        <section id="examples" className="py-12 bg-muted/30">
          <div className="container">
            <div className="text-center mb-16">
              <h2 className="text-section mb-4">Examples</h2>
              <p className="text-body-large text-muted-foreground max-w-2xl mx-auto">
                Explore real-world applications and get inspired by what's possible
              </p>
            </div>

            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 max-w-6xl mx-auto">
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
                    <CardDescription>{example.description}</CardDescription>
                  </CardHeader>
                </Card>
              ))}
            </div>
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
                      <p className="text-body italic text-muted-foreground">
                        "By LLM: A Declarative Framework for Compositional Language Model Programming"
                      </p>
                      <p className="text-sm text-muted-foreground mt-2">
                        Authors et al. (2024) - Conference on Language Models and Applications
                      </p>
                    </div>
                    <div className="border-l-4 border-primary pl-6">
                      <p className="text-body italic text-muted-foreground">
                        "Modular AI Architecture: Principles and Best Practices"
                      </p>
                      <p className="text-sm text-muted-foreground mt-2">
                        Research Team (2024) - Journal of AI Engineering
                      </p>
                    </div>  
                    <div className="border-l-4 border-primary pl-6">
                      <p className="text-body italic text-muted-foreground">
                        "Towards Composable AI: Building Reliable Language Model Systems"
                      </p>
                      <p className="text-sm text-muted-foreground mt-2">
                        Contributors (2023) - International Conference on AI Systems
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
                <div className="flex items-center space-x-2 mb-4">
                  <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center">
                    <span className="text-primary-foreground font-bold text-sm">BL</span>
                  </div>
                  <span className="text-xl font-semibold">By LLM</span>
                </div>
                <p className="text-muted-foreground text-sm">
                  Building the future of AI development with declarative, composable frameworks.
                </p>
              </div>

              <div>
                <h4 className="font-semibold mb-4">Community</h4>
                <ul className="space-y-2 text-sm">
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors flex items-center">
                      <Github className="h-4 w-4 mr-2" />
                      GitHub Discussions
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors flex items-center">
                      <MessageCircle className="h-4 w-4 mr-2" />
                      Discord Server
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors flex items-center">
                      <Users className="h-4 w-4 mr-2" />
                      Community Forum
                    </a>
                  </li>
                </ul>
              </div>

              <div>
                <h4 className="font-semibold mb-4">Resources</h4>
                <ul className="space-y-2 text-sm">
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Documentation
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      API Reference
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Examples
                    </a>
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Tutorials
                    </a>
                  </li>
                </ul>
              </div>

              <div>
                <h4 className="font-semibold mb-4">FAQ</h4>
                <ul className="space-y-2 text-sm">
                  <li>
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
                  </li>
                  <li>
                    <a href="#" className="text-muted-foreground hover:text-primary transition-colors">
                      Contributing
                    </a>
                  </li>
                </ul>
              </div>
            </div>

            <div className="border-t mt-12 pt-8 text-center text-sm text-muted-foreground">
              <p>&copy; 2024 By LLM Project. Built with passion for the AI development community.</p>
            </div>
          </div>
        </footer>
      </div>
    </ThemeProvider>
  );
};

export default Index;