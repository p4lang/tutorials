# Implementing a P4 Calculator

## Introduction

The objective of this tutorial is to implement a basic calculator
using a custom protocol header written in P4. The header will contain
an operation to perform and two operands. When a switch receives a
calculator packet header, it will execute the operation on the
operands, and return the result to the sender.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`calc.p4`, which initially drops all packets.  Your job will be to
extend it to properly implement the calculator logic.

As a first step, compile the incomplete `calc.p4` and bring up a
switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `calc.p4`, and
  
   * start a Mininet instance with one switches (`s1`) connected to
     two hosts (`h1`, `h2`).
   * The hosts are assigned IPs of `10.0.1.1` and `10.0.1.2`.

2. We've written a small Python-based driver program that will allow
you to test your calculator. You can run the driver program directly
from the Mininet command prompt:

```
mininet> h1 python calc.py 
> 
```

3. The driver program will provide a new prompt, at which you can type
basic expressions. The test harness will parse your expression, and
prepare a packet with the corresponding operator and operands. It will
then send a packet to the switch for evaluation. When the switch
returns the result of the computation, the test program will print the
result. However, because the calculator program is not implemented,
you should see an error message.

```
> 1+1
Didn't receive response
>
```

## Step 2: Implement Calculator

To implement the calculator, you will need to define a custom
calculator header, and implement the switch logic to parse header,
perform the requested operation, write the result in the header, and
return the packet to the sender.

We will use the following header format:

             0                1                  2              3
      +----------------+----------------+----------------+---------------+
      |      P         |       4        |     Version    |     Op        |
      +----------------+----------------+----------------+---------------+
      |                              Operand A                           |
      +----------------+----------------+----------------+---------------+
      |                              Operand B                           |
      +----------------+----------------+----------------+---------------+
      |                              Result                              |
      +----------------+----------------+----------------+---------------+
 

-  P is an ASCII Letter 'P' (0x50)
-  4 is an ASCII Letter '4' (0x34)
-  Version is currently 0.1 (0x01)
-  Op is an operation to Perform:
 -   '+' (0x2b) Result = OperandA + OperandB
 -   '-' (0x2d) Result = OperandA - OperandB
 -   '&' (0x26) Result = OperandA & OperandB
 -   '|' (0x7c) Result = OperandA | OperandB
 -   '^' (0x5e) Result = OperandA ^ OperandB
 

We will assume that the calculator header is carried over Ethernet,
and we will use the Ethernet type 0x1234 to indicate the presence of
the header.

Given what you have learned so far, your task is to implement the P4
calculator program. There is no control plane logic, so you need only
worry about the data plane implementation.

A working calculator implementation will parse the custom headers,
execute the mathematical operation, write the result in the result
field, and return the packet to the sender.

## Step 3: Run your solution

Follow the instructions from Step 1.  This time, you should see the
correct result:

```
> 1+1
2
>
```