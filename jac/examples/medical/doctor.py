class Doctor:
    def __init__(self, name):
        self.name = name
        self.patients = []
        self.receivables = 0

    def add_patient(self, patient):
        """Adds a patient to the doctor's list."""
        self.patients.append(patient)
        patient.doctors.append(self)

    def update_receivables(self, amount):
        """Updates the doctor's receivables after a claim is processed."""
        self.receivables += amount
        print(f"Dr. {self.name}'s receivables updated by ${amount}. New total: ${self.receivables}")


class Patient:
    def __init__(self, name):
        self.name = name
        self.balance = 200  # Example starting balance
        self.doctors = []

    def update_balance(self, amount):
        """Updates the patient's balance after a claim is processed."""
        self.balance += amount


    def add_doctor(self, doctor):
        """Adds a doctor to the patient's list."""
        self.doctors.append(doctor)
        doctor.patients.append(self)


class Claim:
    def __init__(self, patient, doctor, cost, diagnosis):
        self.patient = patient
        self.doctor = doctor
        self.cost = cost
        self.diagnosis = diagnosis
        self.status = "Submitted" # The claim has its own lifecycle!

    def __repr__(self):
        return f"Claim for {self.patient.name} with Dr. {self.doctor.name} for ${self.cost}"
    

class InsuranceProvider:
    def __init__(self):
        self.network = []  # List of doctors in the network
        self.deductible = 200  # Example deductible amount
    def add_doctor_to_network(self, doctor):
        """Adds a doctor to the insurance provider's network."""
        self.network.append(doctor)


    def check_network_status(self, doctor):
        """Checks if the doctor is in the insurance provider's network."""
        if doctor in self.network:
            return True
        
        return False
    
    def check_patient_deductible(self, patient):
        """Checks if the patient's deductible has been met."""
        if patient.balance >= self.deductible:
            return True
        
        return False
    

    def process_claim(self, claim):
        # To do its job, the provider needs to know about the doctor and patient
        is_in_network = self.check_network_status(claim.doctor)
        deductible_met = self.check_patient_deductible(claim.patient)

        if is_in_network and deductible_met:
            claim.status = "Approved"
            # Now the claim has to tell everyone...
            claim.patient.update_balance(20) # Tell patient their co-pay
            claim.doctor.update_receivables(230) # Tell doctor they're getting paid

    

# --- Let's model a visit ---
dr_house = Doctor("Gregory House")
john_smith = Patient("John Smith")

# John adds Dr. House to his list of doctors
john_smith.add_doctor(dr_house)
# Dr. House adds John as a patient
dr_house.add_patient(john_smith)

# Create an insurance provider and add Dr. House to its network
blue_cross = InsuranceProvider()
blue_cross.add_doctor_to_network(dr_house)

# John visits Dr. House for a checkup
claim1 = Claim(john_smith, dr_house, 250, "Routine Checkup")


blue_cross.process_claim(claim1)