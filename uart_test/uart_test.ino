uint8_t data_pins[] = {2, 3, 4, 5, 6, 7, 8, 9};
uint8_t nrst_pin = A4;
uint8_t ncs_pin = A3;
uint8_t rw_pin = A2;
uint8_t addr_pins[] = {A0, A1};

void set_address(uint8_t addr) {
    digitalWrite(A0, addr & 0x1);
    digitalWrite(A1, (addr>>1)&0x1);
}

void set_data(uint8_t data) {
    for(int i=0; i<8; i++) {
        digitalWrite(data_pins[i], (data>>i)&0x1);
    }
}

uint8_t get_data() {
    uint8_t data = 0;
    for(int i=0; i<8; i++) {
        data |= digitalRead(data_pins[i])<<i;
    }
    return data;
}

void set_data_dir(int dir) {
    for(int i=0; i<8; i++) {
        pinMode(data_pins[i], dir);
    }
}

void write_reg(uint8_t addr, uint8_t data) {

    set_address(addr);

    digitalWrite(rw_pin, LOW);

    set_data(data);
    set_data_dir(OUTPUT);

    digitalWrite(ncs_pin, LOW);
    delayMicroseconds(1);
    digitalWrite(ncs_pin, HIGH);
    delayMicroseconds(1);

    set_data_dir(INPUT);
    digitalWrite(rw_pin, HIGH);
}

uint8_t read_reg(uint8_t addr) {
    set_address(addr);

    // HIGH is default
    // digitalWrite(rw_pin, HIGH);

    // bus is input by default
    //set_data_dir(INPUT);

    digitalWrite(ncs_pin, LOW);
    delayMicroseconds(1);

    uint8_t data = get_data();
    digitalWrite(ncs_pin, HIGH);

    return data;
}

void send_char(char ch) {
    while(read_reg(0) & 0x1);
    write_reg(0, ch);
}

char recv_char() {
    while( (read_reg(0) & 0x2) != 0 );
    return read_reg(1);
}

const char charr[] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};

void setup() {
    set_data_dir(INPUT);

    digitalWrite(nrst_pin, HIGH);
    pinMode(nrst_pin, OUTPUT);

    digitalWrite(ncs_pin, HIGH);
    pinMode(ncs_pin, OUTPUT);

    digitalWrite(rw_pin, HIGH);
    pinMode(rw_pin, OUTPUT);

    for(int i=0; i<2; i++) {
        digitalWrite(addr_pins[i], LOW);
        pinMode(addr_pins[i], OUTPUT);
    }

    delay(100);
    Serial.begin(115200);

}

uint8_t ch = 'A';

void loop() {

    for(int i=0; i<sizeof(charr); i++) {
        send_char(charr[i]);
    }
    send_char('\n');

    uint8_t res1 = read_reg(0);
    uint8_t res2 = read_reg(0);
    uint8_t res3 = read_reg(0);
    uint8_t res4 = read_reg(0);
    delay(500);
    Serial.print("status:  ");
    Serial.print(res1, HEX);
    Serial.print(" ");
    Serial.print(res2, HEX);
    Serial.print(" ");
    Serial.print(res3, HEX);
    Serial.print(" ");
    Serial.print(res4, HEX);
    Serial.println();
}
