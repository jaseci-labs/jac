# Medical Software Startup

Welcome to our brand new medical software startup! Our first task is to model the relationship between a `Doctor` and a `Patient`. 

A patient has a doctor. A doctor has a name. Let's code it up!

```python
class Doctor:
    def __init__(self, name):
        self.name = name

class Patient:
    def __init__(self, name, doctor):
        self.name = name
        self.doctor = doctor # A patient has ONE doctor

# --- Let's test it out ---
dr_house = Doctor("Gregory House")
john_smith = Patient("John Smith", dr_house)

print(f"{john_smith.name}'s doctor is Dr. {john_smith.doctor.name}.")
```

Life is good. The code is simple, clean, and does exactly what we asked for. We high-five our teammates and go for lunch.

### Uh Oh... A New Requirement!

We get back from lunch and our Project Manager, Brenda, is at our desk.

**Brenda:** "Hey team! Great work this morning. Just a tiny change: it turns out a `Patient` can see many `Doctors` (a primary care physician, a specialist, etc.). Also, a `Doctor` obviously has many `Patients`. Can you update the model?"

Our simple `self.doctor` attribute is no longer enough. This is a **many-to-many** relationship.

"No problem, Brenda!" we say. The most straightforward solution is to use lists.

```python
class Doctor:
    def __init__(self, name):
        self.name = name
        self.patients = [] # A doctor can have many patients

    def add_patient(self, patient):
        self.patients.append(patient)

class Patient:
    def __init__(self, name):
        self.name = name
        self.doctors = [] # A patient can have many doctors

    def add_doctor(self, doctor):
        self.doctors.append(doctor)

# --- Let's wire it up ---
dr_house = Doctor("Gregory House")
dr_wilson = Doctor("James Wilson")

john_smith = Patient("John Smith")

john_smith.add_doctor(dr_house)
dr_house.add_patient(john_smith)

john_smith.add_doctor(dr_wilson)
dr_wilson.add_patient(john_smith)

print(f"{john_smith.name}'s doctors are: {', '.join(['Dr. ' + doc.name for doc in john_smith.doctors])}")
```

Okay, a bit more complex, but manageable. We've handled the many-to-many relationship. We're feeling pretty good about ourselves.

## The Relationship Gets Complicated

Brenda is back. She looks... anxious.

**Brenda:** "The stakeholders love it! But... they want to actually *bill* for a visit. So when a `Patient` sees a `Doctor`, we need to track the date, the diagnosis, and the cost of that specific visit. Where... does that information go?"

**Us:** "Uhhh..."

Let's think about this.

- Can we put `visit_cost` in the `Patient` class? No, a patient has different costs for different visits with different doctors.
- Can we put it in the `Doctor` class? No, the cost is different for each patient and each visit.

The information (cost, date, diagnosis) doesn't belong to the `Patient` or the `Doctor`. **It belongs to the interaction between them.**

Let's create a new class, `Claim`, to represent this relationship between doctor and patient.

```python
class Doctor:
    def __init__(self, name):
        self.name = name

class Patient:
    def __init__(self, name):
        self.name = name

class Claim:
    def __init__(self, patient, doctor, cost, diagnosis):
        self.patient = patient
        self.doctor = doctor
        self.cost = cost
        self.diagnosis = diagnosis
        self.status = "Submitted" # The claim has its own lifecycle!

    def __repr__(self):
        return f"Claim for {self.patient.name} with Dr. {self.doctor.name} for ${self.cost}"

# --- Let's model a visit ---
dr_house = Doctor("Gregory House")
john_smith = Patient("John Smith")

# John visits Dr. House for a checkup
claim1 = Claim(john_smith, dr_house, 250, "Routine Checkup")

print(claim1)
print(f"Status: {claim1.status}")
```

This is a huge improvement! Our design feels much cleaner. The `Claim` object neatly encapsulates all the information about a specific interaction.

## Houston, We Have a Communication Problem

Brenda is back. She's not even trying to hide her panic.

**Brenda:** "We need `InsuranceProviders`! The `Provider` has to approve a `Claim`. The approval amount depends on the `Doctor`'s network status and the `Patient`'s policy. Once the `Provider` approves it, the `Claim` status must change, the `Patient` needs to be notified of their co-pay, and the `Doctor` needs to know how much they're getting paid. How do they all talk to each other?!"

Let's try to code this directly.

```python
class InsuranceProvider:
    def process_claim(self, claim):
        # To do its job, the provider needs to know about the doctor and patient
        is_in_network = self.check_network_status(claim.doctor)
        deductible_met = self.check_patient_deductible(claim.patient)

        if is_in_network and deductible_met:
            claim.status = "Approved"
            # Now the claim has to tell everyone...
            claim.patient.update_balance(20) # Tell patient their co-pay
            claim.doctor.update_receivables(230) # Tell doctor they're getting paid
```

**Look at that `process_claim` method!** The `Provider` needs a reference to the `Claim`. The `Claim` needs references to the `Patient` and `Doctor` so it can call their methods.

What happens if the `Patient` class changes its `update_balance` method name? The `InsuranceProvider` code breaks! What if the `Doctor` wants a different notification? The `Claim` class has to be changed.

## JAC to the rescue!

This tight coupling is a classic software design problem. When different parts of your system are too dependent on the internal details of other parts, a small change in one place can cause a cascade of failures elsewhere. Our `InsuranceProvider` needs to know the exact method names in `Patient` and `Doctor` to function.

So, how do we fix this? We can decouple the *actions* from the *data*. The data (who a patient is, what a claim costs) can live in a structured, connected way, and the actions (like processing a claim) can be independent agents that walk over this structure.

This is where a graph-based approach using Jac comes in. Instead of objects calling each other's methods directly, we will model our system as a graph and use "walkers" to traverse it.

## Step 1: Modeling Data as a Graph

First, let's get rid of the Python classes and represent everything as **nodes** (the things) and **edges** (the relationships).

In Jac, we define the blueprint for our data like this:

```python
# A person is a foundational concept
node Person {
    has name: str;
}

# Roles that a Person can have
node Doctor {
    has specialty: str;
    has receivables: int = 0;
}

node Patient {
    has balance: int = 0;
}

# The insurance company
node Insurance {
    has name: str;
    has fraction: float = 0.8; # How much they cover by default
}

# The claim itself
node Claim {
    has cost: int;
    has status: str = "Processing";
    has insurance_pays: int = 0;
}
```

Think of `nodes` as our nouns. They hold data but don't have complex methods for interacting with other nodes. They just exist.

Next, we define the relationships between them using **edges**:

```python
# Edges define how nodes are connected
edge has_role {}
edge is_treating {}
edge treated_by {}
edge in_network_with {}
edge has_insurance {}
edge files_claim {}
edge is_processed_by {}
```

Edges are the verbs. An edge connects two nodes, creating a meaningful link, like `(Person) --has_role--> (Doctor)`.

## Step 2: Creating an Independent "Processor"

Remember the problematic `process_claim` method inside the `InsuranceProvider` class? It was doing too much and was too tightly coupled.

In Jac, we pull that logic out into a **walker**. A walker is an independent agent that can travel across the graph of nodes and edges to perform actions.

Let's look at the `ClaimProcessing` walker. It's designed to do one job: process a single claim.

```python
walker ClaimProcessing {
    has claim: Claim;
    has fraction: float = 0; # The coverage amount we'll discover
    has insurance_pays: int = 0;

    # The main logic starts here
    can traverse with Claim entry {
        # Find the patient who filed this claim
        patient = [here <-:files_claim:<-][0];

        # Find that patient's insurance and doctor
        insurance = [patient ->:has_insurance:->];
        doctor = [patient->:treated_by:->][0];

        # Check if the doctor is in the insurance network
        if len(insurance) > 0 {
            # is_connected is a helper that checks if an edge exists
            # between two nodes.
            if is_connected(doctor, in_network_with, insurance[0]) {
                self.fraction = insurance[0].fraction; # Grab the coverage %
                here.status = "Approved";
            }
        }

        # Calculate payment and update the claim node
        self.insurance_pays = int(self.claim.cost * self.fraction);
        here.insurance_pays = self.insurance_pays;

        # Now, visit the patient to update their balance
        visit [here <-:files_claim:<-];
    }
}
```

Look how clean that is! The walker starts at a `Claim` node. It then "walks" along the graph's edges (`<-:files_claim:<-`, `->:has_insurance:->`) to find the `Patient`, `Insurance`, and `Doctor`. It doesn't need to have a `claim.patient` or `claim.doctor` variable passed to it. It discovers the relationships by traversing the graph.

But what about updating the doctor and patient? The walker handles that too, but in a decoupled way.

```python
walker ClaimProcessing {
    # ... (previous code) ...

    # If the walker visits a Doctor node, this ability activates
    can update_doctor with Doctor entry {
        here.receivables += self.insurance_pays;
    }

    # If the walker visits a Patient node, this one activates
    can update_patient with Patient entry {
        here.balance += self.claim.cost - self.insurance_pays;
    }
}
```

The `visit` statement in the main traversal block (`visit [here <-:files_claim:<-];`) sends the walker over to the `Patient` node that is connected to the claim. When the walker "lands" on that `Patient` node, its `update_patient` ability automatically fires. We could easily add a similar `visit` to the doctor to update their receivables. The core logic in `ClaimProcessing` doesn't know or care *how* the `Patient` or `Doctor` node is updated; it just sends a visitor. The node itself handles the update.

## Step 3: Putting It All Together

So how do we build this graph and kick off the process? The `with entry` block is like our `main` function.

```python
with entry {
    # 1. Create the nodes
    blue_cross = spawn Insurance(name="Blue Cross Health Insurance");

    dr_house_person = spawn Person(name="Gregory House");
    dr_house_role = spawn Doctor(specialty="Internal Medicine");

    john_smith_person = spawn Person(name="John Smith");
    john_smith_role = spawn Patient();

    # 2. Create the edges (relationships)
    dr_house_person +>:has_role:+> dr_house_role; # Dr. House IS A Doctor
    john_smith_person +>:has_role:+> john_smith_role; # John Smith IS A Patient

    dr_house_person +>:in_network_with:+> blue_cross; # Link doctor to provider
    john_smith_person +>:has_insurance:+> blue_cross; # Link patient to provider
    john_smith_person +>:treated_by:+> dr_house_person; # Link patient to doctor

    # 3. A medical event happens: a claim is created
    claim = spawn Claim(cost=250);
    john_smith_person +>:files_claim:+> claim; # John files the claim

    # 4. Kick off the walkers!
    spawn claim with ClaimProcessing(claim=claim);
    spawn claim with PrintClaim();
}
```

And that's it! We've successfully modeled a complex, real-world scenario where information is spread out and multiple parties need to be updated. The key benefits are:

- **Decoupling**: The `ClaimProcessing` walker doesn't need to know the inner workings of `Patient` or `Doctor`. It just visits them.
- **Clarity**: The model (nodes and edges) is separate from the logic (walkers). The graph clearly describes the state of the world.
- **Flexibility**: If Brenda comes back and says the `Doctor`'s notification now needs to be an email, we simply modify the `update_doctor` ability in the walker. The `Claim` and `Patient` code remains untouched.