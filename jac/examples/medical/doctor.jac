node Person{
    has name: str;
}

edge has_role{}

node Doctor{
    has specialty: str;
    has receivables: int = 0;
}

node Patient{
    has balance: int = 0;
}

edge is_treating{}
edge treated_by{}

node Insurance{
    has name: str;
    has fraction: float = 0.8;
}

edge in_network_with{}
edge has_insurance{}

node Claim{
    has cost: int;
    has status: str = "Processing";
    has insurance_pays: int = 0;
}

edge files_claim{}
edge is_processed_by{}

def is_connected(start: node, connection: edge, end: node) -> bool{
    if end is None{
        return len([start->:connection:->]) > 0;
    }

    return len([start->:connection:->end]) > 0;
}

walker ClaimProcessing{
    has claim: Claim;
    has fraction: float = 0; #Example: we pay 80% of the claim cost
    has insurance_pays: int = 0;


    can update_doctor with Doctor entry {
        here.receivables += self.insurance_pays;
    }

    can update_patient with Patient entry{
        here.balance += self.claim.cost - self.insurance_pays;
    }

    can update_person with Person entry {
        visit [here ->:has_role:->];
        visit [here --> (`?Person) ->:has_role:->];
    }

    can traverse with Claim entry { 
        patient = [here <-:files_claim:<-][0];
        insurance = [patient ->:has_insurance:->];
        doctor = [patient->:treated_by:->][0];

        if len(insurance) > 0 {
            if is_connected(doctor, in_network_with, insurance[0]){
                self.fraction = insurance[0].fraction;
                here.status = "Approved";
            }   
        }

        self.insurance_pays = int(self.claim.cost * self.fraction);
        here.insurance_pays = self.insurance_pays;
        visit [here <-:files_claim:<-];
    }

}

walker PrintClaim{
    can traverse with Claim entry {
        print("Claim status: ", here.status);
        print("Insurance pays: ", here.insurance_pays);
        print("Claim cost: ", here.cost);
        print("You Pay: ", here.cost - here.insurance_pays);
    }
}


with entry{
    blue_cross = Insurance(" Blue Cross Health Insurance");

    dr_house = Person("Gregory House");
    dr_house +>:has_role:+> Doctor(specialty = "Internal Medicine");
    dr_house +>:in_network_with:+> blue_cross;

    john_smith = Person("John Smith");
    john_smith +>:has_role:+> Patient();
    john_smith +>:has_insurance:+> blue_cross;

    dr_house +>:is_treating:+> john_smith;
    john_smith +>:treated_by:+> dr_house;

    claim = Claim(cost = 2500);
    john_smith +>:files_claim:+> claim;
    claim +>:is_processed_by:+> blue_cross;

    ClaimProcessing(claim) spawn claim;
    PrintClaim() spawn claim;
}