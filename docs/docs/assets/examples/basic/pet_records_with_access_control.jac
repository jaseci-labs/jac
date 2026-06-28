obj PetRecord {
    has:pub name: str,
        species: str;

    has:priv owner_contact: str,
        microchip_id: str;

    has:protect medical_history: list[str] = [],
        last_checkup: str = "";

    def:pub get_basic_info -> str {
        return f"{self.name} is a {self.species}";
    }

    def:protect add_medical_record(record: str) {
        self.medical_history.append(record);
        print(f"Medical record added for {self.name}");
    }

    def:priv validate_contact(contact: str) -> bool {
        return "@" in contact and len(contact) > 5;
    }

    def:pub update_owner_contact(new_contact: str) -> bool {
        if self.validate_contact(new_contact) {
            self.owner_contact = new_contact;
            return True;
        }
        return False;
    }
}

obj VetRecord(PetRecord) {
    has:protect vet_notes: str = "";

    def:pub add_vet_note(note: str) {
        self.add_medical_record(f"Vet note: {note}");
        self.vet_notes = note;
    }

    def:pub get_medical_summary -> str {
        record_count = len(self.medical_history);
        return f"{self.name} has {record_count} medical records";
    }
}

glob pet = PetRecord(
         name="Fluffy",
         species="cat",
         owner_contact="owner@example.com",
         microchip_id="123456789"
     );

with entry {
    print(pet.get_basic_info());
    print(f"Pet name: {pet.name}");
}

glob success = pet.update_owner_contact("new_owner@example.com");

with entry {
    print(f"Contact updated: {success}");
}

glob vet_record = VetRecord(
         name="Rex",
         species="dog",
         owner_contact="owner2@example.com",
         microchip_id="987654321"
     );

with entry {
    vet_record.add_vet_note("Annual checkup - healthy");
    print(vet_record.get_medical_summary());
}
