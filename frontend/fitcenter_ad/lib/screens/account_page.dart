
import 'package:flutter/material.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  String _selectedRole = 'Member';
  String _searchQuery = '';
  String _selectedStatus = 'Tất cả';

  final List<Map<String, dynamic>> _members = [
    {
      'name': 'Nguyễn Văn An',
      'email': 'member1@gmail.com',
      'active': true,
    },
    {
      'name': 'Trần Thị Bình',
      'email': 'member2@gmail.com',
      'active': true,
    },
    {
      'name': 'Lê Minh Cường',
      'email': 'member3@gmail.com',
      'active': false,
    },
  ];

  final List<Map<String, dynamic>> _pts = [
    {
      'name': 'Phạm Minh Đức',
      'email': 'pt1@gmail.com',
      'active': true,
    },
    {
      'name': 'Nguyễn Hoàng Long',
      'email': 'pt2@gmail.com',
      'active': false,
    },
  ];

  List<Map<String, dynamic>> get _accounts =>
      _selectedRole == 'Member' ? _members : _pts;

  List<Map<String, dynamic>> get _filteredAccounts {
    return _accounts.where((account) {
      final name = account['name'].toString().toLowerCase();
      final email = account['email'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final isActive = account['active'] as bool;

      final matchesSearch =
          name.contains(query) || email.contains(query);

      final matchesStatus =
          _selectedStatus == 'Tất cả' ||
              (_selectedStatus == 'Đang hoạt động' && isActive) ||
              (_selectedStatus == 'Đã tạm khóa' && !isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final accounts = _filteredAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hội viên & PT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _showAddAccountDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm tài khoản'),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Member',
                    label: Text('Hội viên'),
                    icon: Icon(Icons.people_outline),
                  ),
                  ButtonSegment(
                    value: 'PT',
                    label: Text('Huấn luyện viên'),
                    icon: Icon(Icons.fitness_center),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedRole = selection.first;
                    _searchQuery = '';
                  });
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc email...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),


            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Lọc theo trạng thái',
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Tất cả',
                    child: Text('Tất cả tài khoản'),
                  ),
                  DropdownMenuItem(
                    value: 'Đang hoạt động',
                    child: Text('Đang hoạt động'),
                  ),
                  DropdownMenuItem(
                    value: 'Đã tạm khóa',
                    child: Text('Đã tạm khóa'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedRole == 'Member'
                          ? 'DANH SÁCH HỘI VIÊN'
                          : 'DANH SÁCH PT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    '${accounts.length} tài khoản',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: accounts.isEmpty
                  ? const Center(
                child: Text('Không tìm thấy tài khoản phù hợp.'),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isActive = account['active'] as bool;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: theme.dividerColor.withOpacity(0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                            primary.withOpacity(0.13),
                            child: Icon(
                              _selectedRole == 'Member'
                                  ? Icons.person_outline
                                  : Icons.fitness_center,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account['name'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  account['email'].toString(),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.12)
                                        : Colors.red.withOpacity(0.12),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive
                                        ? 'Đang hoạt động'
                                        : 'Đã tạm khóa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa tài khoản',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditAccountDialog(account),
                          ),
                          IconButton(
                            tooltip: 'Xóa tài khoản',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteAccount(account),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                account['active'] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showAddAccountDialog() {
    String name = '';
    String email = '';
    String selectedRole = _selectedRole;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm tài khoản'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (value) {
                        name = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      onChanged: (value) {
                        email = value.trim();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Vai trò',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Member',
                          child: Text('Hội viên'),
                        ),
                        DropdownMenuItem(
                          value: 'PT',
                          child: Text('Huấn luyện viên'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final cleanName = name.trim();
                    final cleanEmail = email.trim();

                    if (cleanName.isEmpty ||
                        cleanEmail.isEmpty ||
                        !cleanEmail.contains('@') ||
                        !cleanEmail.contains('.')) {
                      setDialogState(() {
                        errorMessage =
                        'Vui lòng nhập họ tên và email hợp lệ.';
                      });
                      return;
                    }

                    final emailExists = [
                      ..._members,
                      ..._pts,
                    ].any(
                          (account) =>
                      account['email'].toString().toLowerCase() ==
                          cleanEmail.toLowerCase(),
                    );

                    if (emailExists) {
                      setDialogState(() {
                        errorMessage = 'Email này đã tồn tại.';
                      });
                      return;
                    }

                    setState(() {
                      final accounts = selectedRole == 'Member'
                          ? _members
                          : _pts;

                      accounts.add({
                        'name': cleanName,
                        'email': cleanEmail,
                        'active': false,
                      });

                      _selectedRole = selectedRole;
                      _searchQuery = '';
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã thêm tài khoản trên giao diện thử nghiệm.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showEditAccountDialog(Map<String, dynamic> account) {
    String name = account['name'].toString();
    String email = account['email'].toString();
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Sửa tài khoản'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onChanged: (value) => email = value.trim(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final cleanName = name.trim();
                    final cleanEmail = email.trim();

                    if (cleanName.isEmpty ||
                        cleanEmail.isEmpty ||
                        !cleanEmail.contains('@') ||
                        !cleanEmail.contains('.')) {
                      setDialogState(() {
                        errorMessage =
                        'Vui lòng nhập họ tên và email hợp lệ.';
                      });
                      return;
                    }

                    final emailExists = [
                      ..._members,
                      ..._pts,
                    ].any(
                          (item) =>
                      !identical(item, account) &&
                          item['email'].toString().toLowerCase() ==
                              cleanEmail.toLowerCase(),
                    );

                    if (emailExists) {
                      setDialogState(() {
                        errorMessage = 'Email này đã tồn tại.';
                      });
                      return;
                    }

                    setState(() {
                      account['name'] = cleanName;
                      account['email'] = cleanEmail;
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã cập nhật tài khoản thử nghiệm.'),
                      ),
                    );
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final name = account['name'].toString();
    final roleName = _members.contains(account) ? 'hội viên' : 'PT';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: Text(
          'Bạn có chắc chắn muốn xóa $roleName "$name" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _accounts.remove(account);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xóa tài khoản "$name"')),
    );
  }
}
