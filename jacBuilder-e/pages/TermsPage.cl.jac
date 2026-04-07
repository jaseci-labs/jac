"""Terms and Conditions page — public legal page."""
import from "@jac/runtime" { useNavigate }
import from ..components.ui.button { Button }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon }

"""Public Terms and Conditions page at /terms."""
def:pub TermsPage() -> Any {
    navigate = useNavigate();

    return <div className="min-h-screen bg-background flex flex-col">

        <div className="flex justify-center px-6 pt-4 sticky top-0 z-10 bg-background/80" style={{"backdropFilter": "blur(16px)"}}>
            <div className="flex items-center justify-between w-full max-w-[860px] bg-muted/50 border border-border rounded-[100px] py-2 pr-2 pl-[18px]">
                <div className="flex items-center gap-2 cursor-pointer" onClick={lambda { navigate("/"); }}>
                    <img src="/static/assets/logo-builder.png" className="w-[26px] h-[26px] rounded-md" alt="logo" />
                    <div className="text-sm font-bold font-mono tracking-[-0.02em] leading-none">
                        <span className="text-primary">{"jac"}</span>
                        <span className="text-muted-foreground font-medium">{" builder"}</span>
                        <span className="text-muted-foreground font-medium">{" studio"}</span>
                    </div>
                </div>
                <Button
                    variant="ghost"
                    size="xs"
                    onClick={lambda { navigate(-1); }}
                    className="text-muted-foreground hover:text-foreground rounded-full"
                >
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-3.5 mr-1" />
                    {"Back"}
                </Button>
            </div>
        </div>

        <div className="flex-1 flex justify-center px-6 pt-10 pb-16">
            <div className="w-full max-w-[720px]">

                <div className="mb-10">
                    <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-2">{"Terms and Conditions"}</h1>
                    <p className="text-sm text-muted-foreground">{"Last updated: March 27, 2026"}</p>
                </div>

                <div className="text-sm text-muted-foreground leading-relaxed space-y-8">

                    <p>{"Please read these Terms and Conditions carefully before using the Jac Builder Service."}</p>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"1. Definitions"}</h2>
                        <p className="mb-3">{"For the purposes of these Terms and Conditions:"}</p>
                        <ul className="list-disc pl-5 space-y-2">
                            <li><span className="text-foreground font-medium">{"Affiliate"}</span>{": An entity that controls, is controlled by, or is under common control with a party, where 'control' means ownership of 50% or more of the shares, equity interest, or other voting securities."}</li>
                            <li><span className="text-foreground font-medium">{"Company"}</span>{": Jaseci Labs, 5559 Great Hawk Circle, Ann Arbor, MI 48105, USA (also referred to as 'We', 'Us', or 'Our')."}</li>
                            <li><span className="text-foreground font-medium">{"Device"}</span>{": Any device that can access the Service such as a computer, mobile phone, or digital tablet."}</li>
                            <li><span className="text-foreground font-medium">{"Service"}</span>{": Refers to the Jac Builder website, accessible at https://jac-builder.jaseci.org."}</li>
                            <li><span className="text-foreground font-medium">{"Terms"}</span>{": These Terms and Conditions, including any documents expressly incorporated by reference, which govern your access to and use of the Service and form the entire agreement between you and the Company."}</li>
                            <li><span className="text-foreground font-medium">{"Third-Party Service"}</span>{": Any services, content, data, or products provided by a third party that are displayed, included, or linked to through the Service."}</li>
                            <li><span className="text-foreground font-medium">{"You"}</span>{": The individual accessing or using the Service, or the entity on whose behalf such individual is accessing the Service."}</li>
                        </ul>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"2. Acknowledgment"}</h2>
                        <p className="mb-3">{"These Terms govern your use of the Service and constitute the full agreement between you and the Company. By accessing or using the Service, you agree to be bound by these Terms. If you disagree with any part of these Terms, you may not access the Service."}</p>
                        <p>{"Your use of the Service is also subject to our Privacy Policy, which describes how we collect, use, and disclose personal information. Please read it carefully."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"3. Eligibility and Access"}</h2>
                        <p className="mb-3">{"The Jac Builder Service is a developer tool accessible to all users. We do not impose age restrictions on use of the Service. However, if you are accessing the Service on behalf of an organization or legal entity, you represent that you have the authority to bind that entity to these Terms."}</p>
                        <p>{"You are responsible for ensuring your use of the Service complies with any laws or regulations applicable in your jurisdiction."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"4. Acceptable Use"}</h2>
                        <p className="mb-3">{"By using the Service, you agree not to:"}</p>
                        <ul className="list-disc pl-5 space-y-2">
                            <li>{"Use the Service for any unlawful purpose or in violation of any applicable laws or regulations."}</li>
                            <li>{"Attempt to gain unauthorized access to any part of the Service or its related systems or networks."}</li>
                            <li>{"Interfere with or disrupt the integrity or performance of the Service."}</li>
                            <li>{"Reverse engineer, decompile, or disassemble any part of the Service, except as permitted by applicable law."}</li>
                            <li>{"Use the Service to transmit harmful, offensive, or malicious content, including malware or spam."}</li>
                            <li>{"Impersonate any person or entity or misrepresent your affiliation with a person or entity."}</li>
                            <li>{"Collect or harvest data from the Service without our express written permission."}</li>
                        </ul>
                        <p className="mt-3">{"We reserve the right to investigate and take appropriate action, including terminating access, for any violations of these acceptable use standards."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"5. Intellectual Property"}</h2>
                        <p className="mb-3">{"The Service and its original content, features, and functionality are and will remain the exclusive property of Jaseci Labs and its licensors. Our trademarks and trade dress may not be used in connection with any product or service without our prior written consent."}</p>
                        <p>{"You retain ownership of any content or code you create using the Service. By using the Service, you grant Jaseci Labs a limited, non-exclusive license to process your content solely to provide and improve the Service."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"6. Third-Party Links and Services"}</h2>
                        <p className="mb-3">{"Our Service may contain links to third-party websites or services that are not owned or controlled by the Company. We have no control over and assume no responsibility for the content, privacy policies, or practices of any third-party sites or services."}</p>
                        <p className="mb-3">{"We strongly advise you to read the terms and privacy policies of any third-party websites or services you visit. The Company shall not be responsible or liable for any damage or loss caused by or in connection with the use of or reliance on any third-party content, goods, or services."}</p>
                        <p>{"The Service may also display or link to content from Third-Party Services (including social media platforms). The Company does not endorse and assumes no responsibility for any such Third-Party Services. Your use of them is governed by their own terms and policies."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"7. Termination"}</h2>
                        <p className="mb-3">{"We may terminate or suspend your access to the Service immediately, without prior notice or liability, if you breach these Terms or for any other reason at our sole discretion."}</p>
                        <p className="mb-3">{"Upon termination, your right to use the Service ceases immediately. Provisions of these Terms which by their nature should survive termination — including ownership provisions, warranty disclaimers, indemnity, and limitations of liability — shall remain in effect."}</p>
                        <p>{"You may also terminate your use of the Service at any time by simply discontinuing use and, if applicable, deleting your Account."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"8. 'AS IS' and 'AS AVAILABLE' Disclaimer"}</h2>
                        <p className="mb-3">{"The Service is provided to you 'AS IS' and 'AS AVAILABLE' with all faults and defects, without warranty of any kind. To the maximum extent permitted by applicable law, the Company expressly disclaims all warranties, whether express, implied, statutory, or otherwise, including:"}</p>
                        <ul className="list-disc pl-5 space-y-2">
                            <li>{"Implied warranties of merchantability, fitness for a particular purpose, and non-infringement."}</li>
                            <li>{"Warranties that the Service will meet your requirements or achieve intended results."}</li>
                            <li>{"Warranties that the Service will operate without interruption or be error-free."}</li>
                            <li>{"Warranties regarding the accuracy, reliability, or currency of any information provided through the Service."}</li>
                            <li>{"Warranties that the Service or its servers are free from viruses or other harmful components."}</li>
                        </ul>
                        <p className="mt-3">{"Some jurisdictions do not allow the exclusion of certain warranties, so some of the above exclusions may not apply to you."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"9. Limitation of Liability"}</h2>
                        <p className="mb-3">{"To the maximum extent permitted by applicable law, the Company and its suppliers shall not be liable for any special, incidental, indirect, or consequential damages, including but not limited to:"}</p>
                        <ul className="list-disc pl-5 space-y-2">
                            <li>{"Loss of profits, revenue, data, or business opportunities."}</li>
                            <li>{"Business interruption or loss of goodwill."}</li>
                            <li>{"Personal injury or loss of privacy arising from use of the Service."}</li>
                            <li>{"Damages arising from third-party software or hardware used with the Service."}</li>
                        </ul>
                        <p className="mt-3">{"Some jurisdictions do not allow limitations on incidental or consequential damages, so the above limitations may not apply to you. In such cases, liability will be limited to the greatest extent permitted by law."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"10. Indemnification"}</h2>
                        <p>{"You agree to defend, indemnify, and hold harmless the Company, its affiliates, licensors, and service providers, and their respective officers, directors, employees, and agents from and against any claims, liabilities, damages, judgments, awards, losses, costs, or expenses (including reasonable legal fees) arising out of or relating to your violation of these Terms or your use of the Service."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"11. Governing Law"}</h2>
                        <p className="mb-3">{"These Terms are governed by the laws of the State of Michigan, United States, excluding its conflict of law rules. Your use of the Service may also be subject to other local, state, national, or international laws applicable in your jurisdiction."}</p>
                        <p>{"If you are a consumer in the European Union, you also benefit from any mandatory provisions of the law of the country in which you reside, which cannot be excluded by contract."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"12. Dispute Resolution"}</h2>
                        <p className="mb-3">{"If you have any concern or dispute about the Service, you agree to first attempt to resolve it informally by contacting us at info@jaseci.org. We will make reasonable efforts to resolve disputes amicably within 30 days of receiving your notice."}</p>
                        <p>{"If informal resolution fails, disputes shall be subject to the exclusive jurisdiction of the courts of Michigan, United States, unless mandatory consumer protection laws in your country require otherwise."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"13. Severability and Waiver"}</h2>
                        <p className="mb-3"><span className="text-foreground font-medium">{"Severability: "}</span>{"If any provision of these Terms is held to be unenforceable or invalid, that provision will be modified to accomplish its objectives to the greatest extent possible under applicable law, and the remaining provisions will continue in full force and effect."}</p>
                        <p><span className="text-foreground font-medium">{"Waiver: "}</span>{"The failure to exercise a right or require performance of an obligation under these Terms shall not affect a party's ability to exercise such right or require such performance at any time thereafter. A waiver of a breach shall not constitute a waiver of any subsequent breach."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"14. Language"}</h2>
                        <p>{"These Terms and Conditions are written in English. If translated versions are made available, the original English text shall prevail in the event of any conflict or ambiguity."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"15. Changes to These Terms"}</h2>
                        <p className="mb-3">{"We reserve the right to modify or replace these Terms at any time at our sole discretion. If a revision is material, we will make reasonable efforts to provide at least 30 days' notice before the new terms take effect, either by email or by a prominent notice on the Service."}</p>
                        <p>{"By continuing to access or use the Service after revisions become effective, you agree to be bound by the updated Terms. If you do not agree to the new Terms, please stop using the Service."}</p>
                    </div>

                    <div>
                        <h2 className="text-base font-semibold text-foreground mb-3">{"16. Contact Us"}</h2>
                        <p className="mb-3">{"If you have any questions about these Terms and Conditions, please contact us:"}</p>
                        <ul className="list-none space-y-1.5">
                            <li>{"Email: "}<a href="mailto:info@jaseci.org" className="text-primary hover:underline">{"info@jaseci.org"}</a></li>
                            <li>{"Website: "}<a href="https://www.jaseci.org" className="text-primary hover:underline">{"jaseci.org"}</a></li>
                            <li>{"Mailing Address: Jaseci Labs, 5559 Great Hawk Circle, Ann Arbor, MI 48105, United States"}</li>
                        </ul>
                    </div>

                </div>
            </div>
        </div>

        <div className="px-6 py-4 flex justify-center border-t border-border/50">
            <div className="flex items-center gap-3 text-xs text-muted-foreground">
                <span className="cursor-pointer hover:text-foreground" onClick={lambda { navigate("/privacy"); }}>{"Privacy Policy"}</span>
                <span className="text-border">{"/"}</span>
                <span>{"by devs, for devs " + String.fromCharCode(183) + " "}<a href="https://github.com/jaseci-labs/jaseci" className="text-muted-foreground/60 no-underline hover:text-muted-foreground">{"Jaseci Labs"}</a></span>
            </div>
        </div>

    </div>;
}
