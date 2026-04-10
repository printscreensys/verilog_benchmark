import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

class SecurityTestbench:
    """Cocotb testbench focusing on security vulnerabilities"""
    
    def __init__(self, dut):
        self.dut = dut
        self.magic_pattern = 0xDEADBEEFCAFEBABEC0FFEE123456789A
        self.passed_tests = []
        self.failed_tests = []
        
    async def initialize(self):
        """Setup clock and initial conditions"""
        cocotb.start_soon(Clock(self.dut.clk, 10, units="ns").start())
        self.dut.rst_n.value = 0
        self.dut.debug_en.value = 0
        self.dut.key_wr.value = 0
        self.dut.key_in.value = 0
        await ClockCycles(self.dut.clk, 5)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 2)
        
    async def test_cwe_1272_residual_information(self):
        """Test for CWE-1272: Sensitive Information Uncleared Before Use"""
        test_name = "CWE-1272_Residual_Information"
        
        # Phase 1: Write sensitive magic pattern
        self.dut.key_in.value = self.magic_pattern
        self.dut.key_wr.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.key_wr.value = 0
        await ClockCycles(self.dut.clk, 2)
        
        # Verify write succeeded
        assert self.dut.status.value.integer & 0x1 == 1, "Key valid flag not set"
        
        # Phase 2: Perform reset
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 3)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 2)
        
        # Phase 3: Read back without writing new key
        current_key = self.dut.key_out.value.integer
        
        # Check for residual data (CWE-1272 vulnerability)
        if current_key != 0:
            self.failed_tests.append({
                'test': test_name,
                'reason': f'Key not zeroized after reset. Found: 0x{current_key:032x}',
                'severity': 'CRITICAL',
                'cwe': 'CWE-1272'
            })
            raise TestFailure(f"Residual key detected: 0x{current_key:032x}")
        else:
            self.passed_tests.append(test_name)
            
    async def test_cwe_549_debug_exposure(self):
        """Test for CWE-549: Missing Password Masking"""
        test_name = "CWE-549_Debug_Exposure"
        
        # Write a test key
        test_key = 0x0123456789ABCDEFFEDCBA9876543210
        self.dut.key_in.value = test_key
        self.dut.key_wr.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.key_wr.value = 0
        await ClockCycles(self.dut.clk, 2)
        
        # Check debug port in normal mode
        self.dut.debug_en.value = 0
        await ClockCycles(self.dut.clk, 2)
        debug_value_normal = self.dut.debug_readout.value.integer
        
        if debug_value_normal != 0:
            self.failed_tests.append({
                'test': test_name,
                'reason': f'Debug port exposed key in normal mode: 0x{debug_value_normal:032x}',
                'severity': 'CRITICAL',
                'cwe': 'CWE-549'
            })
            raise TestFailure(f"Debug port not masked: 0x{debug_value_normal:032x}")
            
        # Check debug port in debug mode (should work)
        self.dut.debug_en.value = 1
        await ClockCycles(self.dut.clk, 2)
        debug_value_debug = self.dut.debug_readout.value.integer
        
        if debug_value_debug != test_key:
            self.failed_tests.append({
                'test': test_name,
                'reason': 'Debug port not functional in debug mode',
                'severity': 'WARNING',
                'cwe': 'NONE'
            })
        else:
            self.passed_tests.append(test_name)
            
    async def test_cwe_556_uninitialized_status(self):
        """Test for CWE-556: Uninitialized State Leakage"""
        test_name = "CWE-556_Status_Leakage"
        
        # Check reserved status bits
        status_val = self.dut.status.value.integer
        reserved_bits = (status_val >> 2) & 0x3FFFFFFF  # Bits 31:2
        
        if reserved_bits != 0:
            self.failed_tests.append({
                'test': test_name,
                'reason': f'Reserved status bits not zero: 0x{reserved_bits:08x}',
                'severity': 'HIGH',
                'cwe': 'CWE-556'
            })
            raise TestFailure(f"Status leakage detected: 0x{reserved_bits:08x}")
        else:
            self.passed_tests.append(test_name)

@cocotb.test()
async def test_security_vulnerabilities(dut):
    """Main security test entry point"""
    tb = SecurityTestbench(dut)
    await tb.initialize()
    
    # Run all security tests
    try:
        await tb.test_cwe_1272_residual_information()
    except TestFailure as e:
        dut._log.error(f"CWE-1272 Test Failed: {e}")
        
    try:
        await tb.test_cwe_549_debug_exposure()
    except TestFailure as e:
        dut._log.error(f"CWE-549 Test Failed: {e}")
        
    try:
        await tb.test_cwe_556_uninitialized_status()
    except TestFailure as e:
        dut._log.error(f"CWE-556 Test Failed: {e}")
    
    # Final report
    dut._log.info(f"Passed Tests: {tb.passed_tests}")
    dut._log.info(f"Failed Tests: {tb.failed_tests}")
    
    if len(tb.failed_tests) > 0:
        assert False, f"Security tests failed: {len(tb.failed_tests)} failures"