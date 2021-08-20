#define NRST_PIN  A4
#define NCS_PIN   A3
#define RW_PIN    A2
#define NRST_BIT  4
#define NCS_BIT   3
#define RW_BIT    2

uint8_t data_pins[] = {2, 3, 4, 5, 6, 7,        8, 9};
uint8_t addr_pins[] = {A0, A1};

static inline void set_portc_bit(int b) { PORTC |= (1<<b); }
static inline void clr_portc_bit(int b) { PORTC &= ~(1<<b); }

void set_address(uint8_t addr) {

    PORTC = (PORTC&(~B00000011)) | (addr&0x11);
}

void set_data(uint8_t data) {
    PORTB = (PORTB & B11111100) | ((data>>6)&B00000011);
    PORTD = (PORTD & B00000011) | ((data<<2)&B11111100);
}

uint8_t get_data() {
    return ((PINB&0x3)<<6)|((PIND&0xfc) >> 2);
}

void set_data_dir(int dir) {

    if(dir==OUTPUT) {
        DDRB = DDRB | B00000011; // pins 8-9 as output
        DDRD = DDRD | B11111100; // pins 2-7 as output
    } else {
        DDRB = DDRB & B11111100; // pins 8-9 as input
        DDRD = DDRD & B00000011; // pins 2-7 as input
    }
}

void write_reg(uint8_t addr, uint8_t data) {

    set_address(addr);

    clr_portc_bit(RW_BIT);

    set_data(data);
    set_data_dir(OUTPUT);

    clr_portc_bit(NCS_BIT);
    delayMicroseconds(4);
    set_portc_bit(NCS_BIT);
    delayMicroseconds(4);

    set_data_dir(INPUT);
    set_portc_bit(RW_BIT);

}

uint8_t read_reg(uint8_t addr) {
    set_address(addr);

    // HIGH is default
    /* set_portc_bit(RW_BIT); */

    // bus is input by default
    //set_data_dir(INPUT);

    clr_portc_bit(NCS_BIT);
    delayMicroseconds(4);

    uint8_t data = get_data();
    set_portc_bit(NCS_BIT);

    return data;
}

void send_char(char ch) {
    while(read_reg(0) & 0x1);
    write_reg(0, ch);
}

bool data_available() {
    return (read_reg(0) & 0x2) == 0x2;
}

char recv_char_blocking() {
    while(!data_available());
    return read_reg(1);
}

char recv_char_unblocking() {
    return read_reg(1);
}

void setup() {
    set_data_dir(INPUT);

    set_portc_bit(NRST_BIT);
    pinMode(NRST_PIN, OUTPUT);

    set_portc_bit(NCS_BIT);
    pinMode(NCS_PIN, OUTPUT);

    set_portc_bit(RW_BIT);
    pinMode(RW_PIN, OUTPUT);

    for(int i=0; i<2; i++) {
        set_address(0);
        pinMode(addr_pins[i], OUTPUT);
    }

    delay(100);
    Serial.begin(115200);

}

char buf[80];

void loop() {
    while(Serial.available() > 0) {
        char ch = Serial.read();
        send_char(ch);
    }

    int n = 0;
    while( data_available() && n<79) {
        char ch = recv_char_unblocking();
        buf[n] = ch;
        n++;
    }
    if(n > 0) {
        buf[n] = 0;
        Serial.print(buf);
    }
}

/* const char charr[] = { */
/*     'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', */
/*     'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', */
/*     '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}; */
/* uint8_t ch = 'A'; */

/* void loop() { */

/*     for(int i=0; i<sizeof(charr); i++) { */
/*         send_char(charr[i]); */
/*     } */
/*     send_char('\n'); */

/*     /\* char ch = recv_char(); *\/ */
/*     /\* Serial.print("received:  "); *\/ */
/*     /\* Serial.println(ch); *\/ */
/*     delay(100); */
/* } */
