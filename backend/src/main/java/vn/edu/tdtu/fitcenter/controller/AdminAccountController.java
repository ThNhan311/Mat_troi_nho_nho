package vn.edu.tdtu.fitcenter.controller;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.account.*;
import vn.edu.tdtu.fitcenter.service.AdminAccountService;
import java.util.List;
@RestController @RequestMapping("/api/v1/admin") @RequiredArgsConstructor
public class AdminAccountController {
    private final AdminAccountService service;
    @PostMapping("/members") @ResponseStatus(HttpStatus.CREATED)
    public AccountResponse member(Authentication a,@Valid @RequestBody AccountCreateRequest r){return service.create(a.getName(),Role.MEMBER,r);}
    @PostMapping("/personal-trainers") @ResponseStatus(HttpStatus.CREATED)
    public AccountResponse pt(Authentication a,@Valid @RequestBody AccountCreateRequest r){return service.create(a.getName(),Role.PT,r);}
    @GetMapping("/members") public List<AccountResponse> members(Authentication a){return service.list(a.getName(),Role.MEMBER);}
    @GetMapping("/personal-trainers") public List<AccountResponse> pts(Authentication a){return service.list(a.getName(),Role.PT);}
}